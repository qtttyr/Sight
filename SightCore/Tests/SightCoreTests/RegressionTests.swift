import Foundation
import Testing

@testable import SightCore

/// Tests for the fixes that keep Sight honest: no deadlocks, no lost
/// undo, no files silently dropped and no names that make a mess.
@Suite("Scan memory")
struct ScanMemoryRegressionTests {
    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SightMemory-\(UUID().uuidString).json")
    }

    private func rule(_ name: String) -> CategoryRule {
        CategoryRule(
            name: name,
            prompt: "\(name) things",
            destination: URL(fileURLWithPath: "/tmp/\(name)")
        )
    }

    @Test("Reset finishes instead of deadlocking")
    func resetDoesNotDeadlock() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let memory = ScanMemory(url: url)
        let file = FileSnapshot(name: "note.txt", url: URL(fileURLWithPath: "/tmp/note.txt"))
        let decision = RoutingDecision(
            file: file, rule: rule("Work"), score: 0.8, runnerUp: 0, accepted: true, ranking: []
        )
        memory.record(for: file, decision: decision)
        memory.persist()

        // The lock is not recursive, so this used to hang forever.
        memory.reset()
        #expect(memory.cachedEntry(for: file) == nil)
        #expect(memory.count == 0)
    }

    @Test("A dismissed file is remembered as 'keep it here'")
    func dismissal() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let memory = ScanMemory(url: url)
        let file = FileSnapshot(name: "note.txt", url: URL(fileURLWithPath: "/tmp/note.txt"))
        memory.dismiss(files: [file])

        let entry = memory.cachedEntry(for: file)
        #expect(entry != nil)
        #expect(entry?.dismissed == true)
    }

    @Test("Dismissal survives a reload")
    func dismissalSurvivesReload() {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let file = FileSnapshot(name: "note.txt", url: URL(fileURLWithPath: "/tmp/note.txt"))
        let memory = ScanMemory(url: url)
        memory.dismiss(files: [file])
        memory.persist()

        let reloaded = ScanMemory(url: url)
        #expect(reloaded.cachedEntry(for: file)?.dismissed == true)
    }
}

@Suite("Learned examples")
struct ExampleStoreRegressionTests {
    @Test("Adding one example after a reload evicts exactly one")
    func evictionAfterReload() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightExamples-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let rule = UUID()

        let store = ExampleStore(url: url)
        for index in 0..<ExampleStore.capacityPerRule {
            store.add(
                LearnedExample(
                    ruleID: rule,
                    isImage: false,
                    vector: [Float(index), 1],
                    fileName: "f\(index)"
                ))
        }
        store.persist()

        // Every example was learned in the same second, so the dates alone
        // cannot tell them apart. The oldest one has to go, not all of them.
        let reloaded = ExampleStore(url: url)
        reloaded.add(LearnedExample(ruleID: rule, isImage: false, vector: [99, 1], fileName: "new"))
        #expect(reloaded.count(for: rule) == ExampleStore.capacityPerRule)
        #expect(reloaded.vectors(isImage: false)[rule]?.contains { $0[0] == 99 } == true)
    }

    @Test("Examples of different rules do not evict each other")
    func evictionIsPerRule() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightExamples-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let first = UUID()
        let second = UUID()

        let store = ExampleStore(url: url)
        for index in 0..<(ExampleStore.capacityPerRule + 3) {
            store.add(
                LearnedExample(
                    ruleID: first, isImage: false, vector: [Float(index)], fileName: "a\(index)"
                ))
        }
        store.add(LearnedExample(ruleID: second, isImage: false, vector: [1], fileName: "b"))
        #expect(store.count(for: first) == ExampleStore.capacityPerRule)
        #expect(store.count(for: second) == 1)
    }
}

@Suite("Scanning")
struct ScannerTests {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightScan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("One unreadable entry does not lose the whole folder")
    func toleratesBrokenEntries() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("hello".utf8).write(to: root.appendingPathComponent("note.txt"))
        // A symlink to nowhere cannot be read as a file.
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("broken"),
            withDestinationURL: URL(fileURLWithPath: "/nowhere/at/all")
        )

        let files = try DirectoryScanner().scan(root: root)
        #expect(files.contains { $0.name == "note.txt" })
    }

    @Test("An unreadable folder throws instead of looking empty")
    func unreadableRootThrows() {
        let missing = URL(fileURLWithPath: "/nowhere/at/all/sight")
        #expect(throws: (any Error).self) {
            try DirectoryScanner().scan(root: missing)
        }
    }

    @Test("A file that is too fresh is handed back for a retry")
    func freshFileIsDeferred() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightFresh-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("just-written.txt")
        try Data("hello".utf8).write(to: source)

        let journal = Journal(url: root.appendingPathComponent("journal.jsonl"))
        let sorter = Sorter(provider: MockEmbeddingProvider(), journal: journal)
        let rules = [
            CategoryRule(
                name: "Work",
                prompt: "invoice receipt",
                destination: root.appendingPathComponent("Work", isDirectory: true)
            )
        ]
        try await sorter.prepare(rules: rules)

        let result = await sorter.process(
            urls: [source],
            root: root,
            rules: rules,
            config: SightConfig(dimension: .tiny)
        )
        // The file was written a moment ago, so it is not ready yet — but it
        // must come back, not disappear.
        #expect(result.deferred.contains { $0.path == source.path })
        #expect(result.outcomes.isEmpty)
    }
}

@Suite("Moving files")
struct MoveTests {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SightMove-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("A move is written to the journal before it happens")
    func journalIsWrittenFirst() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("note.txt")
        try Data("note".utf8).write(to: source)

        let journal = Journal(url: root.appendingPathComponent("journal.jsonl"))
        let sorter = Sorter(provider: MockEmbeddingProvider(), journal: journal)
        let rule = CategoryRule(
            name: "Work",
            prompt: "invoice receipt",
            destination: root.appendingPathComponent("Work", isDirectory: true)
        )
        try await sorter.prepare(rules: [rule])

        let file = try FileSnapshot(url: source)
        let decision = RoutingDecision(
            file: file, rule: rule, score: 0.9, runnerUp: 0, accepted: true, ranking: []
        )
        let event = try await sorter.commit(decision)
        #expect(event.outcome == .moved)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("Work/note.txt").path))

        // The journal knows about the move, so it can be undone.
        let entries = try await journal.recent(limit: 1)
        #expect(entries.count == 1)
        #expect(entries.first?.destination.lastPathComponent == "note.txt")
    }

    @Test("A file is put back and the journal agrees")
    func undoPutsTheFileBack() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("note.txt")
        try Data("note".utf8).write(to: source)

        let journal = Journal(url: root.appendingPathComponent("journal.jsonl"))
        let sorter = Sorter(provider: MockEmbeddingProvider(), journal: journal)
        let rule = CategoryRule(
            name: "Work",
            prompt: "invoice receipt",
            destination: root.appendingPathComponent("Work", isDirectory: true)
        )
        try await sorter.prepare(rules: [rule])

        let file = try FileSnapshot(url: source)
        let decision = RoutingDecision(
            file: file, rule: rule, score: 0.9, runnerUp: 0, accepted: true, ranking: []
        )
        try await sorter.commit(decision)

        let batch = try await journal.lastBatch()
        #expect(batch.count == 1)
        let restored = try await journal.undo(batch: batch)
        #expect(restored == 1)
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test("The destination is resolved before the file is moved")
    func destinationIsResolved() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("note.txt")
        try Data("note".utf8).write(to: source)

        let executor = SortExecutor()
        let file = try FileSnapshot(url: source)
        let target = try await executor.destination(
            for: file,
            in: root.appendingPathComponent("Work", isDirectory: true),
            root: root,
            newName: "Renamed note.txt"
        )
        #expect(target.lastPathComponent == "Renamed note.txt")
        #expect(FileManager.default.fileExists(atPath: target.deletingLastPathComponent().path))
    }

    @Test("A name that is not a plain file name is refused")
    func safeName() {
        #expect(SortExecutor.safeName("good name.txt", fallback: "x.txt") == "good name.txt")
        #expect(SortExecutor.safeName("../escape.txt", fallback: "x.txt") == "x.txt")
        #expect(SortExecutor.safeName("with/slash.txt", fallback: "x.txt") == "x.txt")
        #expect(SortExecutor.safeName(".hidden", fallback: "x.txt") == "x.txt")
    }
}

@Suite("Naming")
struct NamingTests {
    @Test("A title is a title, not a sentence")
    func headings() {
        #expect(FileNamer.looksLikeHeading("Service Concept"))
        #expect(FileNamer.looksLikeHeading("CATCH NEW SIGNAL"))
        #expect(FileNamer.looksLikeHeading("WarriorHacks 2.0"))
        #expect(FileNamer.looksLikeHeading("ИНСТРУМЕНТЫ ДЛЯ ПРОЕКТОВ"))
        #expect(FileNamer.looksLikeHeading("Black Iris"))

        #expect(!FileNamer.looksLikeHeading("Discovery became much more visual"))
        #expect(!FileNamer.looksLikeHeading("Allow NoNotion — поймать мысль to appear in"))
        #expect(!FileNamer.looksLikeHeading("Sites for developers"))
        #expect(!FileNamer.looksLikeHeading("Ruddarr is an iOS App, open source, companion"))
        #expect(!FileNamer.looksLikeHeading("L.V"))
    }

    @Test("A name carries no stray numbers, dashes or long sentences")
    func sanitize() {
        #expect(FileNamer.sanitize("Payslip Social insurance") == "Payslip Social insurance")
        #expect(FileNamer.sanitize("WarriorHacks 2.0") == "WarriorHacks 2.0")
        #expect(FileNamer.sanitize("Tax return 2026") == "Tax return 2026")

        // A sentence fragment is not a name.
        #expect(FileNamer.sanitize("Payslip – Social insurance -312.00") == nil)
        #expect(FileNamer.sanitize("Allow NoNotion to appear in") == nil)
        #expect(FileNamer.sanitize("Total 312.00") == nil)
        #expect(FileNamer.sanitize("a") == nil)
    }

    @Test("A dangling function word is trimmed away")
    func trimming() {
        #expect(FileNamer.trimToTitle("Discovery became much more visual") == "Discovery became much")
        #expect(FileNamer.trimToTitle("Black Iris") == "Black Iris")
        #expect(FileNamer.trimToTitle("Choose a visual world for") == "Choose a visual")
    }

    @Test("A recognised document type wins over a phrase")
    func templatesWin() {
        let template = NameCandidate(text: "Payslip", isTemplate: true, prior: 0.3)
        let phrase = NameCandidate(text: "Social insurance", isTemplate: false, prior: 0.1)
        let chosen = FileNamer.select([template, phrase], scores: [0.2, 0.9])
        #expect(chosen?.text == "Payslip")
    }

    @Test("A candidate that only barely wins is dropped")
    func marginIsRequired() {
        let first = NameCandidate(text: "Service Concept", isTemplate: false, prior: 0.12)
        let second = NameCandidate(text: "Open Source Apps", isTemplate: false, prior: 0.1)
        // The two are equally close to the document: that is a coin flip.
        #expect(FileNamer.select([first, second], scores: [0.5, 0.5]) == nil)
        // A clear winner is taken.
        #expect(FileNamer.select([first, second], scores: [0.9, 0.4])?.text == "Service Concept")
    }

    @Test("A single candidate is not enough to rename")
    func singleCandidateIsRejected() {
        let only = NameCandidate(text: "Service Concept", isTemplate: false, prior: 0.12)
        #expect(FileNamer.select([only], scores: [0.99]) == nil)
    }

    @Test("A month is only a month when a year says so")
    func monthNeedsAYear() {
        // "may" is an ordinary English word and must not become a date.
        #expect(FileNamer.monthYear(in: "you may need to submit this form") == nil)
        #expect(FileNamer.monthYear(in: "Payslip August 2026") == "Aug 2026")
        #expect(FileNamer.monthYear(in: "Payroll 08/2026") == "Aug 2026")
    }

    @Test("A file whose name already says something is left alone")
    func renameableOnly() {
        let namer = FileNamer()
        let informative = FileContext(
            file: FileSnapshot(name: "quarterly-report.pdf", url: URL(fileURLWithPath: "/tmp/quarterly-report.pdf")),
            payload: .text("quarterly report")
        )
        #expect(!namer.isRenameable(informative))

        let meaningless = FileContext(
            file: FileSnapshot(name: "IMG_0059.PNG", url: URL(fileURLWithPath: "/tmp/IMG_0059.PNG")),
            payload: .image(URL(fileURLWithPath: "/tmp/IMG_0059.PNG"))
        )
        #expect(namer.isRenameable(meaningless))
    }
}
