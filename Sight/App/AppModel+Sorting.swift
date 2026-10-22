import Foundation
import SightCore

extension AppModel {
    func startMonitoring() {
        stopMonitoring()
        guard let rootURL, sorter != nil, modelState.isReady else { return }
        let monitor = FSEventsMonitor()
        monitor.start(root: rootURL) { [weak self] urls in
            Task { @MainActor [weak self] in
                await self?.handleLive(urls: urls)
            }
        }
        self.monitor = monitor
    }

    func stopMonitoring() {
        monitor?.stop()
        monitor = nil
    }

    func runSweep() async {
        guard let sorter, let rootURL, !isSweeping else { return }
        isSweeping = true
        sortProgress = SortProgress(
            processed: 0,
            total: 0,
            currentName: "",
            moved: 0,
            review: 0,
            unrecognized: 0
        )
        defer {
            isSweeping = false
            sortProgress = nil
        }

        // Rules or confidence settings changed since the last sweep? Memory
        // is invalidated wholesale so classifications are re-computed.
        scanMemory.invalidateIfSignatureChanged(
            to: Self.classificationSignature(rules: rules, config: config)
        )

        let summary = await sorter.sweep(
            root: rootURL,
            rules: rules,
            config: config,
            memory: isDemoMode ? nil : scanMemory
        ) { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.sortProgress = progress
            }
        }

        lastSummary = summary
        for event in summary.events.reversed() {
            appendEvent(event)
        }

        if !isDemoMode {
            scanMemory.pruneMissing()
            scanMemory.persist()
            republishRememberedReviews()
        }

        if !isAutoMode {
            pendingDecisions = summary.decisions
                .filter { $0.accepted }
                .sorted { $0.score > $1.score }
        }
    }

    /// Confident decisions that still sit untouched in the watched root from
    /// an earlier session rejoin the review queue, sorted by certainty.
    private func republishRememberedReviews() {
        guard let rootURL else { return }
        let analyzedKeys = Set(scanMemory.awaitingReview.map(\.filePath))
        for entry in scanMemory.awaitingReview {
            let url = URL(fileURLWithPath: entry.filePath)
            guard url.deletingLastPathComponent().standardizedFileURL
                == rootURL.standardizedFileURL
            else { continue }
            guard !pendingDecisions.contains(where: { $0.file.id == entry.filePath })
            else { continue }
            guard let file = try? FileSnapshot(url: url) else { continue }
            let rule = rules.first { $0.id == entry.ruleID }
            pendingDecisions.append(RoutingDecision(
                file: file,
                rule: rule,
                score: entry.score,
                runnerUp: 0,
                accepted: true,
                ranking: rule.map { [($0.id, $0.name, entry.score)] } ?? []
            ))
        }
        pendingDecisions.sort { $0.score > $1.score }
        _ = analyzedKeys
    }

    /// Memory is invalidated by any change to the inputs the classifier sees:
    /// the rules themselves, or the confidence settings.
    static func classificationSignature(
        rules: [CategoryRule],
        config: SightConfig
    ) -> String {
        var parts: [String] = [
            "t\(String(format: "%.3f", config.threshold))",
            "m\(String(format: "%.3f", config.margin))",
            "d\(config.dimension.rawValue)"
        ]
        for rule in rules {
            parts.append("\(rule.id.uuidString)|\(rule.name)|\(rule.prompt)|\(rule.destination.path)|\(rule.threshold.map { String($0) } ?? "-")|\(rule.isEnabled ? "1" : "0")")
        }
        return parts.joined(separator: "\n")
    }

    func handleLive(urls: [URL]) async {
        guard let sorter, let rootURL, !isSweeping, modelState.isReady else { return }
        let outcomes = await sorter.process(urls: urls, root: rootURL, rules: rules, config: config)
        for outcome in outcomes {
            appendEvent(outcome.event)
            if !isDemoMode {
                scanMemory.record(for: outcome.decision.file, decision: outcome.decision)
            }
            if outcome.event.outcome == .review, !isAutoMode {
                if !pendingDecisions.contains(where: { $0.file.id == outcome.decision.file.id }) {
                    pendingDecisions.insert(outcome.decision, at: 0)
                }
            }
        }
    }

    func handleDrop(urls: [URL]) {
        guard let first = urls.first else { return }
        if first.hasDirectoryPath || (try? first.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            setRoot(first)
            return
        }

        guard let rootURL else {
            errorMessage = "Choose a folder first."
            return
        }

        let insideRoot = urls.allSatisfy { url in
            url.deletingLastPathComponent().standardizedFileURL == rootURL.standardizedFileURL
        }
        guard insideRoot else {
            errorMessage = "Sight only sorts files that are already in the watched folder. Drop a folder to change it."
            return
        }
        Task { await self.handleLive(urls: urls) }
    }

    func approve(_ decision: RoutingDecision) async {
        if isDemoMode {
            pendingDecisions.removeAll { $0.id == decision.id }
            appendEvent(SortEvent(
                fileName: decision.file.name,
                category: decision.rule?.name,
                score: decision.score,
                outcome: .moved
            ))
            return
        }
        guard let sorter else { return }
        do {
            let event = try await sorter.commit(decision)
            appendEvent(event)
            pendingDecisions.removeAll { $0.id == decision.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reject(_ decision: RoutingDecision) {
        pendingDecisions.removeAll { $0.id == decision.id }
        if !isDemoMode, decision.rule != nil {
            scanMemory.record(
                for: decision.file,
                decision: RoutingDecision(
                    file: decision.file,
                    rule: decision.rule,
                    score: decision.score,
                    runnerUp: decision.runnerUp,
                    accepted: false,
                    ranking: decision.ranking
                )
            )
            scanMemory.persist()
        }
        appendEvent(SortEvent(
            fileName: decision.file.name,
            category: decision.rule?.name,
            score: decision.score,
            outcome: .skipped,
            message: "Kept in place."
        ))
    }

    func approveAll() async {
        let decisions = pendingDecisions
        for decision in decisions {
            await approve(decision)
        }
    }

    func undoLastMove() async {
        guard !isDemoMode else { return }
        do {
            guard let entry = try await journal.recent(limit: 1).first else { return }
            if try await journal.undo(entry) {
                appendEvent(SortEvent(
                    fileName: entry.fileName,
                    category: entry.category,
                    score: entry.score,
                    outcome: .undone
                ))
            } else {
                errorMessage = "This file can no longer be undone. It may have been moved or renamed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func appendEvent(_ event: SortEvent) {
        events.insert(event, at: 0)
        if events.count > 200 {
            events.removeLast(events.count - 200)
        }
    }

    func dismissReview() {
        pendingDecisions = []
    }

    func test(text: String) async {
        guard let sorter, let rootURL else {
            testDecision = nil
            return
        }
        do {
            testDecision = try await sorter.classify(
                text: text,
                fileName: "test.txt",
                root: rootURL,
                rules: rules,
                config: config
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
