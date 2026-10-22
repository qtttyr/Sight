import Foundation

/// One file the user confirmed belongs in a category. Sight keeps only the
/// embedding (never the file or its text), so learning stays private and tiny.
public struct LearnedExample: Codable, Sendable, Equatable {
    public var ruleID: UUID
    public var isImage: Bool
    /// Normalized embedding, stored as little-endian Float32.
    public var vectorData: Data
    public var fileName: String
    public var date: Date

    public init(ruleID: UUID, isImage: Bool, vector: [Float], fileName: String, date: Date = .now) {
        self.ruleID = ruleID
        self.isImage = isImage
        self.vectorData = vector.withUnsafeBufferPointer { Data(buffer: $0) }
        self.fileName = fileName
        self.date = date
    }

    public var vector: [Float] {
        vectorData.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
    }
}

/// Remembers what the user confirmed, per category. This is how Sight gets
/// better at *your* folders: the next file that resembles an approved one is
/// pulled toward the same category.
public final class ExampleStore: @unchecked Sendable {
    /// Per rule and modality. Older examples fall out first, so the model of
    /// a category follows the user as their habits change.
    public static let capacityPerRule = 48

    private let lock = NSLock()
    private let url: URL
    private var examples: [LearnedExample]
    private var isDirty = false

    public init(url: URL = AppPaths.examplesURL) {
        self.url = url
        self.examples = ExampleStore.load(at: url)
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return examples.count
    }

    public func count(for ruleID: UUID) -> Int {
        lock.lock(); defer { lock.unlock() }
        return examples.filter { $0.ruleID == ruleID }.count
    }

    /// All examples of one modality, grouped by rule.
    public func vectors(isImage: Bool) -> [UUID: [[Float]]] {
        lock.lock(); defer { lock.unlock() }
        var grouped: [UUID: [[Float]]] = [:]
        for example in examples where example.isImage == isImage {
            grouped[example.ruleID, default: []].append(example.vector)
        }
        return grouped
    }

    public func add(_ example: LearnedExample) {
        lock.lock(); defer { lock.unlock() }
        // The same file approved twice must not count twice.
        examples.removeAll {
            $0.ruleID == example.ruleID && $0.isImage == example.isImage
                && $0.fileName == example.fileName
        }
        examples.append(example)
        let sameKind = examples.filter { $0.ruleID == example.ruleID && $0.isImage == example.isImage }
        if sameKind.count > Self.capacityPerRule {
            let overflow = sameKind.count - Self.capacityPerRule
            let doomed = Set(sameKind.sorted { $0.date < $1.date }.prefix(overflow).map(\.date))
            examples.removeAll {
                $0.ruleID == example.ruleID && $0.isImage == example.isImage && doomed.contains($0.date)
            }
        }
        isDirty = true
    }

    /// Drops examples of rules that no longer exist.
    public func retain(ruleIDs: Set<UUID>) {
        lock.lock(); defer { lock.unlock() }
        let before = examples.count
        examples.removeAll { !ruleIDs.contains($0.ruleID) }
        if examples.count != before { isDirty = true }
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        examples = []
        isDirty = true
        write()
    }

    public func persist() {
        lock.lock(); defer { lock.unlock() }
        guard isDirty else { return }
        write()
    }

    private func write() {
        isDirty = false
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(examples).write(to: url, options: .atomic)
        } catch {
            // Learning is an optimization, never a correctness requirement.
        }
    }

    private static func load(at url: URL) -> [LearnedExample] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([LearnedExample].self, from: data)) ?? []
    }
}
