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
    /// Every file that was classified, moved or not.
    public let decisions: [RoutingDecision]
    /// Files that stayed in place and have a proposed category. This is what
    /// the review queue shows: nothing with a candidate is ever dropped.
    public let proposals: [RoutingDecision]
    public let scanned: Int
    public let moved: Int
    public let review: Int
    public let unrecognized: Int
    public let failed: Int
    /// Files answered from memory instead of the model.
    public let skipped: Int
    public let duration: Duration
    /// All moves of this sweep share it, so they undo as one step.
    public let batchID: UUID
    /// Set when the folder itself could not be read. An empty folder and an
    /// unreadable folder look the same otherwise, and the difference matters
    /// a lot to the user.
    public let scanError: String?

    public init(
        events: [SortEvent],
        decisions: [RoutingDecision],
        proposals: [RoutingDecision],
        scanned: Int,
        moved: Int,
        review: Int,
        unrecognized: Int,
        failed: Int,
        skipped: Int,
        duration: Duration,
        batchID: UUID,
        scanError: String? = nil
    ) {
        self.scanError = scanError
        self.events = events
        self.decisions = decisions
        self.proposals = proposals
        self.scanned = scanned
        self.moved = moved
        self.review = review
        self.unrecognized = unrecognized
        self.failed = failed
        self.skipped = skipped
        self.duration = duration
        self.batchID = batchID
    }
}

public struct SortOutcome: Sendable {
    public let decision: RoutingDecision
    public let event: SortEvent

    public init(decision: RoutingDecision, event: SortEvent) {
        self.decision = decision
        self.event = event
    }
}

/// The result of handling a batch of paths that appeared in the watched
/// folder.
public struct ProcessResult: Sendable {
    public let outcomes: [SortOutcome]
    /// Files that were still being written. They are handed back so the
    /// caller can try again in a moment instead of dropping them silently.
    public let deferred: [URL]

    public init(outcomes: [SortOutcome], deferred: [URL]) {
        self.outcomes = outcomes
        self.deferred = deferred
    }
}

/// Where the time of a sweep went. Performance work needs numbers.
public struct SortTimings: Sendable {
    /// Reading and parsing the files.
    public var extract: TimeInterval = 0
    /// The model itself: the text tower and the vision tower.
    public var textEmbed: TimeInterval = 0
    public var imageEmbed: TimeInterval = 0
    /// Comparing against the rules and the learned examples.
    public var compare: TimeInterval = 0
    public var learned: TimeInterval = 0
    /// Finding a better name for a file (OCR included).
    public var naming: TimeInterval = 0
    /// Moving the files on disk.
    public var moving: TimeInterval = 0
    /// Looking for groups that deserve a new folder.
    public var discovery: TimeInterval = 0
    public var files = 0

    public var total: TimeInterval {
        extract + textEmbed + imageEmbed + compare + learned + naming + moving + discovery
    }
}

/// Orchestrates the pipeline: scan → extract → classify → (propose | move).
/// The actor is the single writer for a sweep, which keeps progress and journal
/// ordering deterministic.
public actor Sorter {
    private let provider: any EmbeddingProviding
    private let classifier: ClassificationService
    private let extractor: FileContextExtractor
    private let scanner: DirectoryScanner
    private let executor: SortExecutor
    private let journal: Journal
    private let examples: ExampleStore?
    private let namer = FileNamer()
    private var clusterSettings = ClusterSettings()

    /// The vectors of the files this sweep classified. Folder discovery
    /// needs the very same vectors, and embedding a file twice is the
    /// second most expensive thing Sight does.
    private var fileVectors: [String: (vector: [Float], isImage: Bool)] = [:]
    /// The readable text of those files, for naming a new folder after them.
    private var cachedText: [String: String] = [:]

    /// Timings of the last sweep, for the profiler.
    public private(set) var timings = SortTimings()

    public init(provider: any EmbeddingProviding, journal: Journal, examples: ExampleStore? = nil) {
        self.provider = provider
        self.classifier = ClassificationService(provider: provider, examples: examples)
        self.extractor = FileContextExtractor()
        self.scanner = DirectoryScanner()
        self.executor = SortExecutor()
        self.journal = journal
        self.examples = examples
    }

    public func prepare(rules: [CategoryRule]) async throws {
        try await provider.prepare()
        try await classifier.prepare(rules: rules)
    }

    public func setTuning(_ tuning: ClassificationService.Tuning) async {
        await classifier.setTuning(tuning)
    }

    public func fingerprint(for rule: CategoryRule, dimension: EmbeddingDimension) async -> [Float] {
        await classifier.fingerprint(for: rule, dimension: dimension.rawValue)
    }

    // MARK: - Sweep

    public func sweep(
        root: URL,
        rules: [CategoryRule],
        config: SightConfig,
        memory: ScanMemory? = nil,
        progress: @escaping @Sendable (SortProgress) -> Void
    ) async -> SortSummary {
        let started = ContinuousClock.now
        let batch = UUID()
        timings = SortTimings()
        fileVectors = [:]
        cachedText = [:]
        var scanError: String?
        var files: [FileSnapshot] = []
        do {
            files = try scanner.scan(root: root)
        } catch {
            // The folder itself could not be read. Saying "nothing to sort"
            // here would be a lie the user cannot debug.
            scanError = error.localizedDescription
        }
        var events: [SortEvent] = []
        var decisions: [RoutingDecision] = []
        var proposals: [RoutingDecision] = []
        var moved = 0
        var review = 0
        var unrecognized = 0
        var failed = 0
        var skipped = 0

        for (index, file) in files.enumerated() {
            guard scanner.isReady(file) else { continue }
            defer {
                progress(
                    SortProgress(
                        processed: index + 1,
                        total: files.count,
                        currentName: file.name,
                        moved: moved,
                        review: review,
                        unrecognized: unrecognized
                    ))
            }

            var decision: RoutingDecision
            var dismissed = false
            var fromMemory = false

            if let entry = memory?.cachedEntry(for: file),
                let remembered = self.decision(for: file, from: entry, rules: rules)
            {
                decision = remembered
                dismissed = entry.dismissed ?? false
                fromMemory = true
                skipped += 1
            } else {
                do {
                    decision = try await classify(file: file, rules: rules, config: config)
                } catch {
                    failed += 1
                    events.append(SortEvent(fileName: file.name, outcome: .failed, message: error.localizedDescription))
                    continue
                }
                memory?.record(for: file, decision: decision)
            }
            decisions.append(decision)

            // A file the user already said "keep" about stays put.
            if dismissed { continue }

            do {
                let event = try await apply(decision: decision, config: config, batch: batch)
                switch event.outcome {
                case .moved:
                    moved += 1
                case .review:
                    review += 1
                    proposals.append(decision)
                case .unrecognized:
                    unrecognized += 1
                case .failed:
                    failed += 1
                case .skipped, .undone:
                    break
                }
                if !fromMemory || event.outcome == .moved || event.outcome == .failed {
                    events.append(event)
                }
            } catch {
                failed += 1
                events.append(
                    SortEvent(
                        fileName: file.name,
                        category: decision.rule?.name,
                        outcome: .failed,
                        message: error.localizedDescription
                    ))
            }
        }

        proposals.sort { $0.score > $1.score }
        return SortSummary(
            events: events,
            decisions: decisions,
            proposals: proposals,
            scanned: files.count,
            moved: moved,
            review: review,
            unrecognized: unrecognized,
            failed: failed,
            skipped: skipped,
            duration: ContinuousClock.now - started,
            batchID: batch,
            scanError: scanError
        )
    }

    /// Rebuilds a decision from a remembered classification. The rule must
    /// still exist, otherwise the decision is re-computed from scratch.
    private func decision(
        for file: FileSnapshot,
        from entry: ScanMemoryEntry,
        rules: [CategoryRule]
    ) -> RoutingDecision? {
        let rule = rules.first { $0.id == entry.ruleID && $0.isValid }
        if entry.ruleID != nil && rule == nil { return nil }
        var ranking: [(ruleID: UUID, name: String, score: Float)] = []
        for alternative in entry.alternatives ?? [] {
            guard rules.contains(where: { $0.id == alternative.ruleID && $0.isValid }) else { continue }
            ranking.append((alternative.ruleID, alternative.name, alternative.score))
        }
        if ranking.isEmpty, let rule {
            ranking = [(rule.id, rule.name, entry.score)]
        }
        return RoutingDecision(
            file: file,
            rule: rule,
            score: entry.score,
            runnerUp: entry.runnerUp ?? 0,
            accepted: entry.accepted,
            ranking: ranking,
            reason: entry.reason,
            suggestedName: entry.suggestedName
        )
    }

    // MARK: - Live

    public func process(
        urls: [URL],
        root: URL,
        rules: [CategoryRule],
        config: SightConfig
    ) async -> ProcessResult {
        var outcomes: [SortOutcome] = []
        var deferred: [URL] = []
        let batch = UUID()
        for url in urls {
            guard url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else {
                continue
            }
            guard let file = try? FileSnapshot(url: url),
                file.isRegularFile,
                !file.isDirectory,
                !file.isSymbolicLink,
                !file.isTemporary
            else {
                continue
            }
            // A file that was just written is not ready yet. Handing it back
            // is the difference between "sorted a moment later" and "never
            // sorted at all".
            guard scanner.isReady(file) else {
                deferred.append(url)
                continue
            }
            do {
                let decision = try await classify(file: file, rules: rules, config: config)
                let event = try await apply(decision: decision, config: config, batch: batch)
                outcomes.append(SortOutcome(decision: decision, event: event))
            } catch {
                outcomes.append(
                    SortOutcome(
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
        return ProcessResult(outcomes: outcomes, deferred: deferred)
    }

    // MARK: - Classification

    public func classify(
        file: FileSnapshot,
        rules: [CategoryRule],
        config: SightConfig
    ) async throws -> RoutingDecision {
        let reading = ContinuousClock.now
        let context = extractor.extract(file: file)
        timings.extract += (ContinuousClock.now - reading).seconds
        timings.files += 1

        let decision = try await classifier.classify(
            context: context,
            rules: rules,
            dimension: config.dimension.rawValue,
            confidence: config.confidence
        )
        let inside = await classifier.timings
        timings.textEmbed += inside.textEmbed
        timings.imageEmbed += inside.imageEmbed
        timings.compare += inside.compare
        timings.learned += inside.learned

        // Keep the vectors around: folder discovery compares the leftovers
        // against each other and would otherwise embed every one of them
        // for a second time.
        let vectors = await classifier.lastVectors
        if let image = vectors.image {
            fileVectors[file.id] = (image, true)
        } else if let text = vectors.text {
            fileVectors[file.id] = (text, false)
        }
        cachedText[file.id] = String(context.body.prefix(400))

        guard config.renameFiles, decision.rule != nil else { return decision }
        let naming = ContinuousClock.now
        let name = await suggestedName(for: context)
        timings.naming += (ContinuousClock.now - naming).seconds
        return decision.with(suggestedName: name)
    }

    /// A better name for a file whose current name says nothing.
    ///
    /// Candidates come from the file itself — its title metadata, a
    /// recognised document type, headings in the body or in a screenshot. The
    /// one that best matches the file's own meaning wins. A candidate that
    /// only barely wins is dropped: a wrong rename is worse than no rename.
    private func suggestedName(for context: FileContext) async -> String? {
        guard namer.isRenameable(context) else { return nil }
        let (candidates, reference) = namer.candidates(for: context)
        guard !candidates.isEmpty else { return nil }

        // Templates carry their own authority, so they never need the model.
        var scores = [Float](repeating: 0, count: candidates.count)
        if !candidates.contains(where: \.isTemplate), !reference.isEmpty,
            let raw = try? await provider.embed(text: reference, kind: .classification)
        {
            let query = VectorMath.normalize(raw)
            for (index, candidate) in candidates.enumerated() {
                guard let vector = try? await provider.embed(text: candidate.text, kind: .classification)
                else { continue }
                scores[index] = VectorMath.cosine(query, VectorMath.normalize(vector))
            }
        }

        guard let chosen = FileNamer.select(candidates, scores: scores) else { return nil }
        return namer.finalName(title: chosen.text, for: context.file)
    }

    public func classify(
        text: String,
        fileName: String,
        root: URL,
        rules: [CategoryRule],
        config: SightConfig
    ) async throws -> RoutingDecision {
        let file = FileSnapshot(name: fileName, url: root.appendingPathComponent(fileName))
        let profile = TypeAnalyzer().analyze(file: file)
        let composed = extractor.compose(name: fileName, body: text)
        let context = FileContext(file: file, payload: .text(composed), profile: profile)
        return try await classifier.classify(
            context: context,
            rules: rules,
            dimension: config.dimension.rawValue,
            confidence: config.confidence
        )
    }

    // MARK: - Discovering folders

    public func setClusterSettings(_ settings: ClusterSettings) {
        clusterSettings = settings
    }

    /// Looks at the files that fit no rule and proposes at most a couple of
    /// new folders for groups that clearly belong together.
    public func discoverFolders(
        leftovers: [RoutingDecision],
        rules: [CategoryRule],
        config: SightConfig
    ) async -> [FolderSuggestion] {
        let started = ContinuousClock.now
        defer { timings.discovery += (ContinuousClock.now - started).seconds }
        let settings = clusterSettings
        guard config.suggestFolders, rules.count < settings.maximumRules,
            leftovers.count >= settings.minimumSize
        else { return [] }

        struct Item {
            let decision: RoutingDecision
            let vector: [Float]
            let isImage: Bool
            let text: String
        }
        var items: [Item] = []
        for decision in leftovers {
            // The vector was already computed when the file was classified.
            // Only files that came from memory still have to be embedded.
            var sample: (vector: [Float], isImage: Bool)?
            var body = ""
            if let cached = fileVectors[decision.file.id] {
                sample = cached
                body = cachedText[decision.file.id] ?? ""
            } else {
                let context = extractor.extract(file: decision.file)
                body = String(context.body.prefix(400))
                sample = await classifier.exampleVector(for: context)
            }
            guard let sample else { continue }
            let words = NameCleaner.clean(decision.file.name) + " " + body
            items.append(Item(decision: decision, vector: sample.vector, isImage: sample.isImage, text: words))
        }

        let takenNames = Set(rules.map { $0.name.lowercased() })
            .union(config.dismissedFolders.map { $0.lowercased() })
        var suggestions: [FolderSuggestion] = []

        for isImage in [false, true] {
            let group = items.filter { $0.isImage == isImage }
            guard group.count >= settings.minimumSize else { continue }
            let mean = VectorMath.mean(group.map(\.vector))
            let centered = group.map { VectorMath.normalize(VectorMath.centered($0.vector, removing: mean)) }
            let link = isImage ? settings.imageLink : settings.textLink
            let required = isImage ? settings.imageCoherence : settings.textCoherence

            for members in ClusterMath.cluster(centered, link: link) where members.count >= settings.minimumSize {
                let coherence = ClusterMath.coherence(of: members, in: centered)
                guard coherence >= required else { continue }

                let texts = members.map { group[$0].text }
                let russian = KeywordNamer.isRussian(texts)
                let rawCentroid = VectorMath.mean(members.map { group[$0].vector })

                var name: String?
                var prompt: String?
                var evidence = ""
                let verdict = await classifier.explain(centroid: rawCentroid, isImage: isImage)
                if let verdict, verdict.topicSimilarity >= settings.topicFloor,
                    verdict.runnerUpGap >= settings.topicGap,
                    verdict.topicSimilarity - verdict.ruleSimilarity >= settings.topicOverRule
                {
                    name = verdict.topic.name(russian: russian)
                    prompt = verdict.topic.prompt
                    evidence = String(
                        format: "topic %.2f vs rule %.2f", verdict.topicSimilarity, verdict.ruleSimilarity)
                }
                // A keyword name is only trusted when the files were already
                // doubtful about their current home.
                let doubtful = members.filter { !group[$0].decision.accepted }.count
                if name == nil, doubtful * 2 >= members.count,
                    let keyword = KeywordNamer.sharedKeyword(for: texts)
                {
                    name = keyword
                    prompt = keyword.lowercased()
                    evidence = "shared keyword"
                }
                guard let name, let prompt, !takenNames.contains(name.lowercased()),
                    !suggestions.contains(where: { $0.name == name })
                else { continue }

                suggestions.append(
                    FolderSuggestion(
                        id: UUID(),
                        name: name,
                        prompt: prompt,
                        coherence: coherence,
                        decisions: members.map { group[$0].decision },
                        evidence: evidence
                    ))
            }
        }
        return Array(
            suggestions.sorted { $0.count * 100 + Int($0.coherence * 100) > $1.count * 100 + Int($1.coherence * 100) }
                .prefix(settings.maximumSuggestions)
        )
    }

    // MARK: - Acting on decisions

    public func apply(
        decision: RoutingDecision,
        config: SightConfig,
        batch: UUID? = nil
    ) async throws -> SortEvent {
        guard let rule = decision.rule else {
            return SortEvent(
                fileName: decision.file.name,
                outcome: .unrecognized,
                message: "No category is close enough."
            )
        }
        let shouldMove = decision.accepted && config.mode == .auto && config.autoSortEnabled
        guard shouldMove else {
            return SortEvent(
                fileName: decision.file.name,
                category: rule.name,
                score: decision.score,
                outcome: .review,
                message: decision.accepted ? nil : "Worth a quick check."
            )
        }
        return try await commit(decision, batch: batch)
    }

    /// Moves a file because the user said so. The confirmation also teaches
    /// Sight: the file becomes an example for the chosen category.
    public func approve(
        _ decision: RoutingDecision,
        as rule: CategoryRule? = nil,
        batch: UUID? = nil
    ) async throws -> SortEvent {
        let final = rule.map { decision.corrected(to: $0) } ?? decision
        guard let target = final.rule else { return try await commit(final, batch: batch) }
        // The file is read *before* it moves; once it is gone there is
        // nothing left to learn from.
        let sample = await exampleSample(for: decision.file, ruleID: target.id)
        let event = try await commit(final, batch: batch)
        if let sample {
            examples?.add(sample)
            examples?.persist()
        }
        return event
    }

    /// Moves a decision even when the app is in Review mode.
    public func commit(_ decision: RoutingDecision, batch: UUID? = nil) async throws -> SortEvent {
        guard let rule = decision.rule else {
            return SortEvent(fileName: decision.file.name, outcome: .unrecognized)
        }
        let root = decision.file.url.deletingLastPathComponent()
        // The destination is resolved first so the journal can record the
        // intent before the file moves. If the app dies in between, the
        // journal holds an entry for a file that never arrived — harmless.
        // The other way round, a moved file would have no undo at all.
        let target = try await executor.destination(
            for: decision.file,
            in: rule.destination,
            root: root,
            newName: decision.suggestedName
        )
        try await journal.record(
            JournalEntry(
                fileName: decision.file.name,
                source: decision.file.url,
                destination: target,
                category: rule.name,
                score: decision.score,
                batchID: batch
            ))
        let moving = ContinuousClock.now
        _ = try await executor.move(decision.file, to: target, root: root)
        timings.moving += (ContinuousClock.now - moving).seconds
        return SortEvent(
            fileName: decision.file.name,
            category: rule.name,
            score: decision.score,
            outcome: .moved,
            message: decision.suggestedName.map { "Renamed to \($0)" }
        )
    }

    private func exampleSample(for file: FileSnapshot, ruleID: UUID) async -> LearnedExample? {
        guard examples != nil else { return nil }
        let context = extractor.extract(file: file)
        guard let sample = await classifier.exampleVector(for: context) else { return nil }
        return LearnedExample(
            ruleID: ruleID,
            isImage: sample.isImage,
            vector: sample.vector,
            fileName: file.name
        )
    }

    /// Teaches Sight that a file belongs to a rule without moving it (used
    /// by evaluation and by "this was right" signals).
    public func learn(file: FileSnapshot, ruleID: UUID) async {
        guard let sample = await exampleSample(for: file, ruleID: ruleID) else { return }
        examples?.add(sample)
        examples?.persist()
    }
}
