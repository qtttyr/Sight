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
        evictOverflow()
        isDirty = true
    }

    /// Keeps every rule within its capacity.
    ///
    /// The oldest examples fall out first. They are identified by position,
    /// never by date: dates are stored with second precision, so several
    /// examples learned in the same second would otherwise be treated as one
    /// and a single new example would wipe all of them.
    private func evictOverflow() {
        let kinds = Set(examples.map { ExampleKind(ruleID: $0.ruleID, isImage: $0.isImage) })
        for kind in kinds {
            let indices = examples.indices.filter {
                examples[$0].ruleID == kind.ruleID && examples[$0].isImage == kind.isImage
            }
            guard indices.count > Self.capacityPerRule else { continue }
            let overflow = indices.count - Self.capacityPerRule
            // Sorted by date, and by position for equal dates, so the oldest
            // examples fall out in the order they were learned.
            let oldest = indices.sorted { a, b in
                if examples[a].date != examples[b].date { return examples[a].date < examples[b].date }
                return a < b
            }.prefix(overflow)
            let doomed = Set(oldest)
            examples = examples.enumerated().filter { !doomed.contains($0.offset) }.map(\.element)
        }
    }

    private struct ExampleKind: Hashable {
        let ruleID: UUID
        let isImage: Bool
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
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(examples).write(to: url, options: .atomic)
            // Only a successful write clears the flag: a failed write has to
            // be retried, not forgotten.
            isDirty = false
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
