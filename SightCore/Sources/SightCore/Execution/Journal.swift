import Foundation

public struct JournalEntry: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let fileName: String
    public let source: URL
    public let destination: URL
    public let category: String
    public let score: Float
    /// Moves made together (one sweep, one "Approve all") share a batch and
    /// are undone together.
    public let batchID: UUID?

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        fileName: String,
        source: URL,
        destination: URL,
        category: String,
        score: Float,
        batchID: UUID? = nil
    ) {
        self.batchID = batchID
        self.id = id
        self.date = date
        self.fileName = fileName
        self.source = source
        self.destination = destination
        self.category = category
        self.score = score
    }
}

/// Append-only history of every move. It is deliberately human-readable JSONL:
/// users can inspect it, and the undo path does not need a database.
public actor Journal {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func record(_ entry: JournalEntry) throws {
        try ensureFileExists()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(entry)
        data.append(0x0A)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    public func recent(limit: Int = 100) throws -> [JournalEntry] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = data.split(separator: 0x0A).compactMap { line in
            try? decoder.decode(JournalEntry.self, from: Data(line))
        }
        return Array(entries.suffix(limit).reversed())
    }

    /// The moves of the most recent batch that can still be undone, newest
    /// first. Moves recorded without a batch count as a batch of their own.
    public func lastBatch() throws -> [JournalEntry] {
        let fileManager = FileManager.default
        let all = try recent(limit: 2_000)
        guard let newest = all.first(where: { fileManager.fileExists(atPath: $0.destination.path) })
        else { return [] }
        guard let batchID = newest.batchID else { return [newest] }
        return all.filter {
            $0.batchID == batchID && fileManager.fileExists(atPath: $0.destination.path)
        }
    }

    /// Undoes every entry, newest first. Returns how many were restored.
    @discardableResult
    public func undo(batch entries: [JournalEntry]) throws -> Int {
        var restored = 0
        for entry in entries {
            if try undo(entry) { restored += 1 }
        }
        return restored
    }

    @discardableResult
    public func undo(_ entry: JournalEntry) throws -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: entry.destination.path) else { return false }
        guard !fileManager.fileExists(atPath: entry.source.path) else { return false }
        try fileManager.createDirectory(
            at: entry.source.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.moveItem(at: entry.destination, to: entry.source)
        return true
    }

    public func clear() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }


    private func ensureFileExists() throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }
}
