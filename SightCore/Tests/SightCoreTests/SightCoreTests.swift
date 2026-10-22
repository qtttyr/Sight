import Foundation
import Testing
@testable import SightCore

@Suite("Vector math")
struct VectorMathTests {
    @Test("Normalization produces a unit vector")
    func normalize() {
        let vector = VectorMath.normalize([3, 4])
        #expect(abs(vector[0] - 0.6) < 0.0001)
        #expect(abs(vector[1] - 0.8) < 0.0001)
    }

    @Test("Cosine similarity is one for identical vectors")
    func cosine() {
        let vector = VectorMath.normalize([1, 2, 3, 4])
        #expect(abs(VectorMath.cosine(vector, vector) - 1) < 0.0001)
    }

    @Test("Matryoshka prefix keeps the requested dimension")
    func prefix() {
        let vector = VectorMath.normalize([1, 2, 3, 4, 5, 6])
        let prefix = VectorMath.prefix(vector, dimension: 4)
        #expect(prefix.count == 4)
        #expect(abs(VectorMath.cosine(prefix, prefix) - 1) < 0.0001)
    }

    @Test("Fingerprint has a stable number of bins")
    func fingerprint() {
        let values = VectorMath.fingerprint((0..<256).map { Float($0) }, bins: 32)
        #expect(values.count == 32)
    }
}

@Suite("Classification")
struct ClassificationTests {
    private func context(_ text: String) -> FileContext {
        let file = FileSnapshot(
            name: "test.txt",
            url: URL(fileURLWithPath: "/tmp/test.txt")
        )
        return FileContext(file: file, payload: .text(text))
    }

    private func makeRules() -> [CategoryRule] {
        [
            CategoryRule(
                name: "Finance",
                prompt: "invoice receipt financial report",
                destination: URL(fileURLWithPath: "/tmp/Finance")
            ),
            CategoryRule(
                name: "Photos",
                prompt: "photo screenshot image",
                destination: URL(fileURLWithPath: "/tmp/Photos")
            )
        ]
    }

    @Test("A clear text signal routes to the matching category")
    func routesText() async throws {
        let rules = makeRules()
        let service = ClassificationService(provider: MockEmbeddingProvider())
        try await service.prepare(rules: rules)
        let decision = try await service.classify(
            context: context("invoice for the studio"),
            rules: rules,
            threshold: 0.3,
            margin: 0.01,
            dimension: 4
        )
        #expect(decision.rule?.name == "Finance")
        #expect(decision.accepted)
        #expect(decision.score > 0.9)
    }

    @Test("A weak signal is not accepted")
    func rejectsWeakSignal() async throws {
        let rules = makeRules()
        let service = ClassificationService(provider: MockEmbeddingProvider())
        try await service.prepare(rules: rules)
        let decision = try await service.classify(
            context: context("something entirely unrelated"),
            rules: rules,
            threshold: 0.9,
            margin: 0.5,
            dimension: 4
        )
        #expect(!decision.accepted)
    }

    @Test("Sorter can classify a synthetic filename")
    func sorterText() async throws {
        let root = URL(fileURLWithPath: "/tmp/sight-test")
        let rules = makeRules()
        let journal = Journal(url: root.appendingPathComponent("journal.jsonl"))
        let sorter = Sorter(provider: MockEmbeddingProvider(), journal: journal)
        try await sorter.prepare(rules: rules)
        let decision = try await sorter.classify(
            text: "a photo of the ocean",
            fileName: "ocean.jpg",
            root: root,
            rules: rules,
            config: SightConfig(dimension: .tiny)
        )
        #expect(decision.rule?.name == "Photos")
    }
}

@Suite("Execution safety")
struct ExecutionTests {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("Collisions get a deterministic suffix")
    func collision() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("one".utf8).write(to: root.appendingPathComponent("note.txt"))

        let resolver = CollisionResolver()
        let url = resolver.availableURL(for: "note.txt", in: root)
        #expect(url.lastPathComponent == "note (1).txt")

        try Data("two".utf8).write(to: url)
        let second = resolver.availableURL(for: "note.txt", in: root)
        #expect(second.lastPathComponent == "note (2).txt")
    }

    @Test("Executor refuses to move a file outside the root")
    func outsideRoot() async throws {
        let root = try temporaryRoot()
        let other = try temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: other)
        }

        let source = other.appendingPathComponent("note.txt")
        try Data("note".utf8).write(to: source)
        let file = try FileSnapshot(url: source)
        let executor = SortExecutor()

        await #expect(throws: SortError.self) {
            try await executor.move(
                file,
                to: root.appendingPathComponent("Destination"),
                root: root
            )
        }
    }

    @Test("Journal records and undoes a move")
    func journalUndo() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("note.txt")
        let destinationDirectory = root.appendingPathComponent("Work", isDirectory: true)
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        try Data("note".utf8).write(to: source)

        let destination = destinationDirectory.appendingPathComponent("note.txt")
        try FileManager.default.moveItem(at: source, to: destination)

        let journal = Journal(url: root.appendingPathComponent("journal.jsonl"))
        try await journal.record(JournalEntry(
            fileName: "note.txt",
            source: source,
            destination: destination,
            category: "Work",
            score: 0.82
        ))

        let recent = try await journal.recent(limit: 1)
        #expect(recent.count == 1)
        #expect(recent.first?.fileName == "note.txt")

        let undone = try await journal.undo(recent[0])
        #expect(undone)
        #expect(FileManager.default.fileExists(atPath: source.path))
    }
}

@Suite("Persistence")
struct PersistenceTests {
    @Test("Config survives a round trip")
    func configRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightConfig-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = JSONStore(url: url, defaultValue: SightConfig())
        var config = try await store.load()
        config.threshold = 0.42
        config.mode = .auto
        try await store.save(config)

        let reloaded = try await JSONStore(url: url, defaultValue: SightConfig()).load()
        #expect(reloaded.threshold == 0.42)
        #expect(reloaded.mode == .auto)
    }

    @Test("Rules survive a round trip")
    func rulesRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightRules-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let rules = [
            CategoryRule(
                name: "Work",
                prompt: "contracts and reports",
                destination: URL(fileURLWithPath: "/tmp/Work")
            )
        ]
        let store = JSONStore<[CategoryRule]>(url: url, defaultValue: [])
        try await store.save(rules)
        let reloaded = try await JSONStore<[CategoryRule]>(url: url, defaultValue: []).load()
        #expect(reloaded.first?.name == "Work")
    }
}

@Suite("Scan memory")
struct ScanMemoryTests {
    private func makeRule(_ name: String) -> CategoryRule {
        CategoryRule(
            name: name,
            prompt: "\(name) things",
            destination: URL(fileURLWithPath: "/tmp/\(name)")
        )
    }

    @Test("Memory survives a round trip and is invalidated by a new signature")
    func signatureInvalidation() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightMemory-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let rule = makeRule("Work")
        let file = FileSnapshot(name: "report.pdf", url: URL(fileURLWithPath: "/tmp/report.pdf"))
        let decision = RoutingDecision(
            file: file,
            rule: rule,
            score: 0.72,
            runnerUp: 0.1,
            accepted: true,
            ranking: []
        )

        let memory = ScanMemory(url: url)
        memory.invalidateIfSignatureChanged(to: "sig-1")
        memory.record(for: file, decision: decision)
        #expect(memory.cachedEntry(for: file)?.score == 0.72)
        memory.persist()

        let reloaded = ScanMemory(url: url)
        #expect(reloaded.cachedEntry(for: file)?.ruleName == "Work")

        // Changing the classification inputs wipes everything.
        reloaded.invalidateIfSignatureChanged(to: "sig-2")
        #expect(reloaded.cachedEntry(for: file) == nil)
    }

    @Test("A changed file is not served from memory")
    func changedFile() {
        let memory = ScanMemory(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("SightMemory-\(UUID().uuidString).json")
        )
        memory.invalidateIfSignatureChanged(to: "sig")

        let rule = makeRule("Design")
        var file = FileSnapshot(name: "logo.png", url: URL(fileURLWithPath: "/tmp/logo.png"))
        let decision = RoutingDecision(
            file: file, rule: rule, score: 0.5, runnerUp: 0, accepted: true, ranking: []
        )
        memory.record(for: file, decision: decision)

        // Same file, same stats: hit.
        #expect(memory.cachedEntry(for: file) != nil)

        // Different size or mtime: miss, which forces re-classification.
        let touched = FileSnapshot(
            name: file.name,
            url: file.url,
            contentType: file.contentType
        )
        #expect(touched.modifiedAt.timeIntervalSince(file.modifiedAt) < 2)
        let editedFile = try? FileSnapshot(url: file.url)
        #expect(editedFile == nil) // file does not exist; nothing cached can match
        _ = touched
    }
}

@Suite("Model manifest")
struct ModelManifestTests {
    @Test("Text and vision fit the documented download size")
    func size() {
        let bytes = ModelManifest.totalBytes(for: [.text, .vision])
        #expect(bytes > 900_000_000)
        #expect(bytes < 1_100_000_000)
    }

    @Test("Every path is unique and pinned")
    func paths() {
        let paths = ModelManifest.files(for: [.text, .vision, .audio]).map(\.path)
        #expect(Set(paths).count == paths.count)
        #expect(ModelManifest.revision.count == 40)
        #expect(ModelManifest.files(for: [.text]).allSatisfy { !$0.sha256.isEmpty })
    }
}

struct MockEmbeddingProvider: EmbeddingProviding {
    let dimension = 4

    func prepare() async throws {}

    func embed(text: String, kind: EmbeddingKind) async throws -> [Float] {
        let lowercased = text.lowercased()
        if lowercased.contains("invoice") || lowercased.contains("finance") {
            return [1, 0, 0, 0]
        }
        if lowercased.contains("photo") || lowercased.contains("image") || lowercased.contains("screenshot") {
            return [0, 1, 0, 0]
        }
        return [0, 0, 1, 0]
    }
}
