import Foundation

public struct SortProgress: Sendable {
    public let processed: Int
    public let total: Int
    public let currentName: String
    public let moved: Int
    public let review: Int
    public let unrecognized: Int

    public init(processed: Int, total: Int, currentName: String, moved: Int, review: Int, unrecognized: Int) {
        self.processed = processed
        self.total = total
        self.currentName = currentName
        self.moved = moved
        self.review = review
        self.unrecognized = unrecognized
    }
}

public struct SortSummary: Sendable {
    public let events: [SortEvent]
    public let decisions: [RoutingDecision]
    public let scanned: Int
    public let moved: Int
    public let review: Int
    public let unrecognized: Int
    public let failed: Int
    /// Files SkipMemory answered from memory instead of the model.
    public let skipped: Int
    public let duration: Duration
}

public struct SortOutcome: Sendable {
    public let decision: RoutingDecision
    public let event: SortEvent

    public init(decision: RoutingDecision, event: SortEvent) {
        self.decision = decision
        self.event = event
    }
}

/// Orchestrates the pipeline: scan → extract → embed → classify → (review | move).
/// The actor is the single writer for a sweep, which keeps progress and journal
/// ordering deterministic.
public actor Sorter {
    private let provider: any EmbeddingProviding
    private let classifier: ClassificationService
    private let extractor: FileContextExtractor
    private let scanner: DirectoryScanner
    private let executor: SortExecutor
    private let journal: Journal

    public init(provider: any EmbeddingProviding, journal: Journal) {
        self.provider = provider
        self.classifier = ClassificationService(provider: provider)
        self.extractor = FileContextExtractor()
        self.scanner = DirectoryScanner()
        self.executor = SortExecutor()
        self.journal = journal
    }

    public func prepare(rules: [CategoryRule]) async throws {
        try await provider.prepare()
        try await classifier.prepare(rules: rules)
    }

    public func fingerprint(for rule: CategoryRule, dimension: EmbeddingDimension) async -> [Float] {
        await classifier.fingerprint(for: rule, dimension: dimension.rawValue)
    }

    public func sweep(
        root: URL,
        rules: [CategoryRule],
        config: SightConfig,
        memory: ScanMemory? = nil,
        progress: @escaping @Sendable (SortProgress) -> Void
    ) async -> SortSummary {
        let started = ContinuousClock.now
        let files = (try? scanner.scan(root: root)) ?? []
        var events: [SortEvent] = []
        var decisions: [RoutingDecision] = []
        var moved = 0
        var review = 0
        var unrecognized = 0
        var failed = 0
        var skipped = 0

        for (index, file) in files.enumerated() {
            guard scanner.isReady(file) else { continue }

            // Already sorted, already reviewed or already skipped, and the
            // file has not changed since: answer from memory, not the model.
            if let remembered = memory?.cachedEntry(for: file), let decision = self.decision(for: file, from: remembered, rules: rules) {
                decisions.append(decision)
                skipped += 1
                memory?.record(for: file, decision: decision) // refreshes last seen
                progress(SortProgress(
                    processed: index + 1,
                    total: files.count,
                    currentName: file.name,
                    moved: moved,
                    review: review,
                    unrecognized: unrecognized
                ))
                continue
            }

            do {
                let decision = try await classify(file: file, rules: rules, config: config)
                decisions.append(decision)
                memory?.record(for: file, decision: decision)
                let event = try await apply(decision: decision, config: config)
                events.append(event)
                switch event.outcome {
                case .moved: moved += 1
                case .review: review += 1
                case .unrecognized: unrecognized += 1
                case .failed: failed += 1
                case .skipped, .undone: break
                }
            } catch {
                failed += 1
                events.append(SortEvent(
                    fileName: file.name,
                    outcome: .failed,
                    message: error.localizedDescription
                ))
            }

            progress(SortProgress(
                processed: index + 1,
                total: files.count,
                currentName: file.name,
                moved: moved,
                review: review,
                unrecognized: unrecognized
            ))
        }

        return SortSummary(
            events: events,
            decisions: decisions,
            scanned: files.count,
            moved: moved,
            review: review,
            unrecognized: unrecognized,
            failed: failed,
            skipped: skipped,
            duration: ContinuousClock.now - started
        )
    }

    /// Rebuilds a routing decision from a remembered classification. The rule
    /// must still exist and carry the same id, otherwise the decision is
    /// re-computed from scratch.
    private func decision(
        for file: FileSnapshot,
        from entry: ScanMemoryEntry,
        rules: [CategoryRule]
    ) -> RoutingDecision? {
        let rule = rules.first { $0.id == entry.ruleID }
        if entry.ruleID != nil && rule == nil { return nil }
        let ranking: [(ruleID: UUID, name: String, score: Float)] =
            rule.map { [($0.id, $0.name, entry.score)] } ?? []
        return RoutingDecision(
            file: file,
            rule: rule,
            score: entry.score,
            runnerUp: 0,
            accepted: entry.accepted,
            ranking: ranking
        )
    }

    public func process(
        urls: [URL],
        root: URL,
        rules: [CategoryRule],
        config: SightConfig
    ) async -> [SortOutcome] {
        var outcomes: [SortOutcome] = []
        for url in urls {
            guard url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else {
                continue
            }
            guard let file = try? FileSnapshot(url: url),
                  file.isRegularFile,
                  !file.isDirectory,
                  !file.isSymbolicLink,
                  !file.isTemporary,
                  scanner.isReady(file) else {
                continue
            }
            do {
                let decision = try await classify(file: file, rules: rules, config: config)
                let event = try await apply(decision: decision, config: config)
                outcomes.append(SortOutcome(decision: decision, event: event))
            } catch {
                outcomes.append(SortOutcome(
                    decision: RoutingDecision(
                        file: file,
                        rule: nil,
                        score: 0,
                        runnerUp: 0,
                        accepted: false,
                        ranking: []
                    ),
                    event: SortEvent(
                        fileName: file.name,
                        outcome: .failed,
                        message: error.localizedDescription
                    )
                ))
            }
        }
        return outcomes
    }

    public func classify(
        file: FileSnapshot,
        rules: [CategoryRule],
        config: SightConfig
    ) async throws -> RoutingDecision {
        let context = extractor.extract(file: file)
        return try await classifier.classify(
            context: context,
            rules: rules,
            threshold: config.threshold,
            margin: config.margin,
            dimension: config.dimension.rawValue
        )
    }

    public func classify(
        text: String,
        fileName: String,
        root: URL,
        rules: [CategoryRule],
        config: SightConfig
    ) async throws -> RoutingDecision {
        let file = FileSnapshot(name: fileName, url: root.appendingPathComponent(fileName))
        let context = FileContext(file: file, payload: .text(text))
        return try await classifier.classify(
            context: context,
            rules: rules,
            threshold: config.threshold,
            margin: config.margin,
            dimension: config.dimension.rawValue
        )
    }

    public func apply(decision: RoutingDecision, config: SightConfig) async throws -> SortEvent {
        guard let rule = decision.rule else {
            return SortEvent(
                fileName: decision.file.name,
                outcome: .unrecognized,
                message: "No category is close enough."
            )
        }
        guard decision.accepted else {
            return SortEvent(
                fileName: decision.file.name,
                category: rule.name,
                score: decision.score,
                outcome: .review,
                message: "Low confidence."
            )
        }

        let shouldMove = config.mode == .auto && config.autoSortEnabled
        guard shouldMove else {
            return SortEvent(
                fileName: decision.file.name,
                category: rule.name,
                score: decision.score,
                outcome: .review
            )
        }

        return try await commit(decision)
    }

    /// Moves a reviewed decision even when the app is in Review mode. This is
    /// the explicit "approve" action and the only path the UI uses for it.
    public func commit(_ decision: RoutingDecision) async throws -> SortEvent {
        guard let rule = decision.rule else {
            return SortEvent(
                fileName: decision.file.name,
                outcome: .unrecognized
            )
        }
        let destination = try await executor.move(
            decision.file,
            to: rule.destination,
            root: decision.file.url.deletingLastPathComponent()
        )
        try await journal.record(JournalEntry(
            fileName: decision.file.name,
            source: decision.file.url,
            destination: destination,
            category: rule.name,
            score: decision.score
        ))
        return SortEvent(
            fileName: decision.file.name,
            category: rule.name,
            score: decision.score,
            outcome: .moved
        )
    }
}
