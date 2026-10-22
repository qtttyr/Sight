import Foundation

public struct ScanMemoryAlternative: Codable, Sendable, Equatable {
    public var ruleID: UUID
    public var name: String
    public var score: Float
}

/// One remembered classification outcome for a single file at the watched root.
public struct ScanMemoryEntry: Codable, Sendable, Equatable {
    public var fileName: String
    public var filePath: String
    public var modifiedAt: Date
    public var fileSize: Int64
    public var ruleID: UUID?
    public var ruleName: String?
    public var score: Float
    public var accepted: Bool
    public var recordedAt: Date
    public var runnerUp: Float?
    public var reason: String?
    public var alternatives: [ScanMemoryAlternative]?
    /// The user chose "keep in place" for this exact file version.
    public var dismissed: Bool?
    public var suggestedName: String?

    public init(
        fileName: String,
        filePath: String,
        modifiedAt: Date,
        fileSize: Int64,
        ruleID: UUID?,
        ruleName: String?,
        score: Float,
        accepted: Bool,
        recordedAt: Date,
        runnerUp: Float? = nil,
        reason: String? = nil,
        alternatives: [ScanMemoryAlternative]? = nil,
        dismissed: Bool? = nil,
        suggestedName: String? = nil
    ) {
        self.suggestedName = suggestedName
        self.runnerUp = runnerUp
        self.reason = reason
        self.alternatives = alternatives
        self.dismissed = dismissed
        self.fileName = fileName
        self.filePath = filePath
        self.modifiedAt = modifiedAt
        self.fileSize = fileSize
        self.ruleID = ruleID
        self.ruleName = ruleName
        self.score = score
        self.accepted = accepted
        self.recordedAt = recordedAt
    }
}

struct ScanMemoryFile: Codable, Sendable {
    var signature: String
    var entries: [String: ScanMemoryEntry]
}

/// Remembers what a sweep or a live drop already decided about each file, so
/// the next sweep over the same folder skips unchanged files instead of
/// re-running inference on them.
///
/// Memory is keyed by absolute path and invalidated when the file changes
/// (size or modification date) or when the classification settings change —
/// a different set of rules, threshold, margin or dimension.
public final class ScanMemory: @unchecked Sendable {
    private let lock = NSLock()
    private let url: URL
    private var file: ScanMemoryFile
    private var isDirty = false

    public init(url: URL = AppPaths.scanMemoryURL) {
        self.url = url
        self.file = ScanMemory.load(at: url)
    }

    /// Discards every remembered decision when rules or confidence settings
    /// changed. Cheap: only compares a combined signature string.
    public func invalidateIfSignatureChanged(to newSignature: String) {
        lock.lock()
        defer { lock.unlock() }
        guard file.signature != newSignature else { return }
        file.signature = newSignature
        file.entries = [:]
        isDirty = true
    }

    /// Returns the remembered decision only if the file has not changed since
    /// it was recorded.
    public func cachedEntry(for fileSnapshot: FileSnapshot) -> ScanMemoryEntry? {
        lock.lock()
        defer { lock.unlock() }
        let key = fileSnapshot.id
        guard let entry = file.entries[key] else { return nil }
        guard entry.fileSize == fileSnapshot.size,
              abs(entry.modifiedAt.timeIntervalSince(fileSnapshot.modifiedAt)) < 2
        else { return nil }
        return entry
    }

    public func record(
        for fileSnapshot: FileSnapshot,
        decision: RoutingDecision,
        dismissed: Bool = false
    ) {
        lock.lock()
        defer { lock.unlock() }
        file.entries[fileSnapshot.id] = ScanMemoryEntry(
            fileName: fileSnapshot.name,
            filePath: fileSnapshot.id,
            modifiedAt: fileSnapshot.modifiedAt,
            fileSize: fileSnapshot.size,
            ruleID: decision.rule?.id,
            ruleName: decision.rule?.name,
            score: decision.score,
            accepted: decision.accepted,
            recordedAt: .now,
            runnerUp: decision.runnerUp,
            reason: decision.reason,
            alternatives: decision.ranking.prefix(4).map {
                ScanMemoryAlternative(ruleID: $0.ruleID, name: $0.name, score: $0.score)
            },
            dismissed: dismissed ? true : nil,
            suggestedName: decision.suggestedName
        )
        isDirty = true
    }

    /// How many entries are remembered right now.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return file.entries.count
    }

    /// Drops entries for files that no longer exist at their remembered path.
    /// Keeps the store proportional to the watched folder.
    public func pruneMissing() {
        lock.lock()
        defer { lock.unlock() }
        var removed = false
        for (key, entry) in file.entries where FileManager.default.fileExists(atPath: entry.filePath) == false {
            file.entries[key] = nil
            removed = true
        }
        if removed { isDirty = true }
    }

    public func persist() {
        lock.lock()
        defer { lock.unlock() }
        guard isDirty else { return }
        isDirty = false
        ScanMemory.write(file: file, to: url)
    }

    /// Forgets every remembered decision.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        file.entries = [:]
        isDirty = true
        persist()
    }

    // MARK: - Disk

    private static func load(at url: URL) -> ScanMemoryFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ScanMemoryFile(signature: "", entries: [:])
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ScanMemoryFile.self, from: data)
        } catch {
            return ScanMemoryFile(signature: "", entries: [:])
        }
    }

    private static func write(file: ScanMemoryFile, to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(file)
            try data.write(to: url, options: .atomic)
        } catch {
            // Memory is an optimization, never a correctness requirement.
        }
    }
}
