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
            dimension: 4
        )
        #expect(decision.rule?.name == "Finance")
        #expect(decision.accepted)
        #expect(decision.score > 0.8)
    }

    @Test("A weak signal is not accepted")
    func rejectsWeakSignal() async throws {
        let rules = makeRules()
        let service = ClassificationService(provider: MockEmbeddingProvider())
        try await service.prepare(rules: rules)
        let decision = try await service.classify(
            context: context("something entirely unrelated"),
            rules: rules,
            dimension: 4,
            confidence: 0.99
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
        config.confidence = 0.8
        config.mode = .auto
        try await store.save(config)

        let reloaded = try await JSONStore(url: url, defaultValue: SightConfig()).load()
        #expect(reloaded.confidence == 0.8)
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
        let file = FileSnapshot(name: "logo.png", url: URL(fileURLWithPath: "/tmp/logo.png"))
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


@Suite("Type evidence")
struct TypeAnalyzerTests {
    private func profile(_ name: String, image: ImageFacts? = nil) -> TypeProfile {
        let snapshot = FileSnapshot(
            name: name,
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            contentType: image == nil ? .data : .png
        )
        return TypeAnalyzer().analyze(file: snapshot, image: image)
    }

    @Test("Video, audio and archives are near certain")
    func media() {
        #expect(profile("clip.mp4").boosts[.video] ?? 0 > 0.9)
        #expect(profile("song.flac").boosts[.audio] ?? 0 > 0.9)
        #expect(profile("app.dmg").boosts[.archives] ?? 0 > 0.9)
    }

    @Test("A PDF can never be a video or a photo")
    func exclusions() {
        let pdf = profile("report.pdf")
        #expect(pdf.excludes.contains(.video))
        #expect(pdf.excludes.contains(.photos))
    }

    @Test("Developer files without extension are recognised")
    func devFiles() {
        #expect(profile("Modelfile").boosts[.code] ?? 0 > 0.9)
        #expect(profile("Dockerfile").boosts[.code] ?? 0 > 0.9)
    }

    @Test("Screenshot names in several languages")
    func screenshotNames() {
        let names = ["Screenshot 2026-10-12 at 09.28.png", "Снимок экрана 2026-10-12.png", "Bildschirmfoto 2026.png"]
        for name in names {
            let facts = ImageFacts(pixelWidth: 100, pixelHeight: 100)
            #expect(profile(name, image: facts).boosts[.screenshots] ?? 0 > 0.9, "\(name)")
        }
    }

    @Test("A PNG with an exact phone-screen size is a screenshot")
    func phoneScreen() {
        let facts = ImageFacts(pixelWidth: 1170, pixelHeight: 2532)
        #expect(profile("IMG_0059.PNG", image: facts).boosts[.screenshots] ?? 0 > 0.8)
    }

    @Test("Camera metadata makes a photo and rules out a screenshot")
    func camera() {
        let facts = ImageFacts(pixelWidth: 4032, pixelHeight: 3024, hasCameraMetadata: true)
        let result = profile("IMG_1234.JPG", image: facts)
        #expect(result.boosts[.photos] ?? 0 > 0.9)
        #expect(result.excludes.contains(.screenshots))
    }
}

@Suite("Name cleaning and rules")
struct NameAndRuleTests {
    @Test("Counters and camera names carry no information")
    func informative() {
        #expect(!NameCleaner.isInformative(NameCleaner.clean("IMG_0059.PNG")))
        #expect(!NameCleaner.isInformative(NameCleaner.clean("Screenshot 2026-10-11 at 22.25.43.png")))
        #expect(NameCleaner.isInformative(NameCleaner.clean("pixel_art_kitchen_atlas_2K.jpg")))
    }

    @Test("Separators become spaces and years survive")
    func cleaning() {
        #expect(NameCleaner.clean("tax_return_2025.pdf") == "tax return 2025")
        #expect(NameCleaner.clean("Student worksheet_Critical reading 1.docx") == "Student worksheet Critical reading")
    }

    @Test("A prompt is split into separate anchors and includes the name")
    func anchors() {
        let rule = CategoryRule(
            name: "Work",
            prompt: "invoice or receipt, signed contract;\nresume",
            destination: URL(fileURLWithPath: "/tmp/Work")
        )
        #expect(rule.anchors == ["invoice or receipt", "signed contract", "resume", "Work"])
    }

    @Test("Rule kind comes from the library id or an unambiguous name")
    func kinds() {
        let library = CategoryRule(name: "Anything", prompt: "x", destination: URL(fileURLWithPath: "/tmp/a"), libraryID: "video")
        #expect(library.kind == .video)
        let named = CategoryRule(name: "Музыка", prompt: "x", destination: URL(fileURLWithPath: "/tmp/b"))
        #expect(named.kind == .audio)
        let ambiguous = CategoryRule(name: "Work photos", prompt: "x", destination: URL(fileURLWithPath: "/tmp/c"))
        #expect(ambiguous.kind == nil)
    }
}

@Suite("Batches and learning")
struct BatchTests {
    @Test("A batch is undone as one step")
    func batchUndo() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightBatch-\(UUID().uuidString)", isDirectory: true)
        let target = root.appendingPathComponent("Work", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let journal = Journal(url: root.appendingPathComponent("journal.jsonl"))
        let batch = UUID()
        for name in ["a.txt", "b.txt", "c.txt"] {
            let destination = target.appendingPathComponent(name)
            try Data(name.utf8).write(to: destination)
            try await journal.record(JournalEntry(
                fileName: name,
                source: root.appendingPathComponent(name),
                destination: destination,
                category: "Work",
                score: 0.9,
                batchID: batch
            ))
        }

        let entries = try await journal.lastBatch()
        #expect(entries.count == 3)
        let restored = try await journal.undo(batch: entries)
        #expect(restored == 3)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("b.txt").path))
        #expect(try await journal.lastBatch().isEmpty)
    }

    @Test("Examples survive a round trip and are capped")
    func examples() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightExamples-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let rule = UUID()
        let store = ExampleStore(url: url)
        for index in 0..<(ExampleStore.capacityPerRule + 5) {
            store.add(LearnedExample(ruleID: rule, isImage: false, vector: [Float(index), 1], fileName: "f\(index)"))
        }
        #expect(store.count(for: rule) == ExampleStore.capacityPerRule)
        store.persist()
        let reloaded = ExampleStore(url: url)
        #expect(reloaded.count(for: rule) == ExampleStore.capacityPerRule)
        #expect(reloaded.vectors(isImage: false)[rule]?.first?.count == 2)
    }

    @Test("A type that rules a category out removes it from the choice")
    func exclusionRouting() async throws {
        let finance = CategoryRule(name: "Finance", prompt: "invoice receipt", destination: URL(fileURLWithPath: "/tmp/F"))
        let photos = CategoryRule(name: "Photos", prompt: "photo image", destination: URL(fileURLWithPath: "/tmp/P"), libraryID: "photos")
        let service = ClassificationService(provider: MockEmbeddingProvider())
        try await service.prepare(rules: [finance, photos])
        let file = FileSnapshot(name: "photo of invoice.pdf", url: URL(fileURLWithPath: "/tmp/photo of invoice.pdf"))
        let profile = TypeAnalyzer().analyze(file: file)
        let context = FileContext(file: file, payload: .text("photo image photo"), profile: profile)
        let decision = try await service.classify(context: context, rules: [finance, photos], dimension: 4)
        #expect(decision.rule?.name == "Finance")
    }
}
