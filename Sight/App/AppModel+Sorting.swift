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

        let summary = await sorter.sweep(root: rootURL, rules: rules, config: config) { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.sortProgress = progress
            }
        }

        lastSummary = summary
        for event in summary.events.reversed() {
            appendEvent(event)
        }
        if !isAutoMode {
            pendingDecisions = summary.decisions
                .filter { $0.accepted }
                .sorted { $0.score > $1.score }
        }
    }

    func handleLive(urls: [URL]) async {
        guard let sorter, let rootURL, !isSweeping, modelState.isReady else { return }
        let outcomes = await sorter.process(urls: urls, root: rootURL, rules: rules, config: config)
        for outcome in outcomes {
            appendEvent(outcome.event)
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
