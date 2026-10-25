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
        if let scanError = summary.scanError {
            // An unreadable folder must not look like an empty one.
            errorMessage = "Sight could not read the watched folder: \(scanError)"
        }
        for event in summary.events.reversed() {
            appendEvent(event)
        }

        if !isDemoMode {
            scanMemory.pruneMissing()
            scanMemory.persist()
        }

        // Every file that has a candidate category and was not moved lands in
        // the queue: confident ones first, doubtful ones after, nothing lost.
        pendingDecisions = summary.proposals
        await refreshFolderSuggestions(from: summary)
    }

    // MARK: - New folders

    /// Files that fit no current rule, offered to the discovery step.
    private func leftovers(in summary: SortSummary) -> [RoutingDecision] {
        return Self.discoveryCandidates(summary.decisions, proposals: summary.proposals)
    }

    /// Everything that was routed by meaning alone and is still in the
    /// folder: doubtful files and confident ones alike, because a group can
    /// have a confident-looking home that is still the wrong place for it.
    /// Files decided by hard evidence (type, metadata) never take part.
    nonisolated static func discoveryCandidates(
        _ decisions: [RoutingDecision],
        proposals: [RoutingDecision]
    ) -> [RoutingDecision] {
        let waiting = Set(proposals.map(\.id))
        return decisions.filter { decision in
            guard waiting.contains(decision.id) else { return false }
            return !decision.accepted || decision.reason?.hasPrefix("Matches") == true
        }
        .prefix(150).map { $0 }
    }

    func refreshFolderSuggestions(from summary: SortSummary) async {
        guard let sorter, !isDemoMode else { return }
        let found = await sorter.discoverFolders(
            leftovers: leftovers(in: summary),
            rules: rules,
            config: config
        )
        // In Auto mode a strong, clearly named group gets its folder right
        // away; otherwise the user decides with one click.
        if isAutoMode {
            var created: [FolderSuggestion] = []
            for suggestion in found where suggestion.count >= 6 && suggestion.coherence >= 0.4 {
                await acceptSuggestion(suggestion)
                created.append(suggestion)
            }
            folderSuggestions = found.filter { candidate in !created.contains { $0.id == candidate.id } }
        } else {
            folderSuggestions = found
        }
    }

    /// Creates the folder and its rule, then moves the group into it.
    func acceptSuggestion(_ suggestion: FolderSuggestion) async {
        guard let rootURL else { return }
        let destination = rootURL.appendingPathComponent(Self.folderName(from: suggestion.name), isDirectory: true)
        guard let rule = addRule(name: suggestion.name, prompt: suggestion.prompt, destination: destination) else {
            return
        }
        try? await sorter?.prepare(rules: rules)
        let batch = UUID()
        var moved = 0
        for decision in suggestion.decisions {
            if await approve(decision, as: rule, batch: batch) { moved += 1 }
        }
        folderSuggestions.removeAll { $0.id == suggestion.id }
        if moved > 0 {
            notice = "Created “\(suggestion.name)” and sorted \(moved) \(moved == 1 ? "file" : "files") into it."
        }
    }

    func dismissSuggestion(_ suggestion: FolderSuggestion) {
        config.dismissedFolders.append(suggestion.name)
        saveConfig()
        folderSuggestions.removeAll { $0.id == suggestion.id }
    }

    /// Memory is invalidated by any change to the inputs the classifier sees:
    /// the rules themselves, the confidence bar, and the classifier itself.
    static func classificationSignature(
        rules: [CategoryRule],
        config: SightConfig
    ) -> String {
        var parts: [String] = [
            "engine\(Self.engineVersion)",
            "r\(config.renameFiles ? 1 : 0)",
            "c\(String(format: "%.3f", config.confidence))",
            "d\(config.dimension.rawValue)",
            "v\(config.loadVision ? 1 : 0)",
        ]
        for rule in rules {
            parts.append(
                "\(rule.id.uuidString)|\(rule.name)|\(rule.prompt)|\(rule.destination.path)|\(rule.threshold.map { String($0) } ?? "-")|\(rule.isEnabled ? "1" : "0")"
            )
        }
        return parts.joined(separator: "\n")
    }

    /// Bumped whenever the classifier's behavior changes, so decisions made
    /// by an older engine are never served from memory.
    static let engineVersion = 4

    /// Files that appeared in the watched folder but were still being written.
    /// They are retried until they settle.
    /// Sweeps, but says why it cannot when something is missing. A button
    /// that does nothing at all is the worst kind of broken.
    func runSweepWithFeedback() async {
        guard modelState.isReady else {
            errorMessage = "Sight needs the local model before it can sort anything. Open Settings to download it."
            return
        }
        guard rootURL != nil else {
            errorMessage = "Choose the folder Sight should watch first."
            return
        }
        await runSweep()
    }

    func handleLive(urls: [URL]) async {
        guard !isSweeping, modelState.isReady else { return }
        for url in urls { deferredURLs[url.standardizedFileURL.path] = url }
        await drainDeferredURLs()
    }

    /// Sorts everything that is waiting, and schedules another pass for the
    /// files that were not ready yet. Without this a file dropped into the
    /// folder would be seen once, judged "too fresh" and never touched again.
    private func drainDeferredURLs() async {
        guard let sorter, let rootURL, !deferredURLs.isEmpty else { return }
        let result = await sorter.process(
            urls: Array(deferredURLs.values),
            root: rootURL,
            rules: rules,
            config: config
        )

        for outcome in result.outcomes {
            deferredURLs.removeValue(forKey: outcome.decision.file.id)
            appendEvent(outcome.event)
            if !isDemoMode, outcome.event.outcome != .failed {
                scanMemory.record(for: outcome.decision.file, decision: outcome.decision)
            }
            if outcome.event.outcome == .review {
                if !pendingDecisions.contains(where: { $0.file.id == outcome.decision.file.id }) {
                    pendingDecisions.insert(outcome.decision, at: 0)
                }
            }
        }
        if !isDemoMode { scanMemory.persist() }

        let stillWaiting = result.deferred
        for url in stillWaiting { deferredURLs[url.standardizedFileURL.path] = url }
        guard !stillWaiting.isEmpty else {
            deferredRetry?.cancel()
            deferredRetry = nil
            return
        }
        deferredRetry?.cancel()
        deferredRetry = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1_200))
            guard !Task.isCancelled else { return }
            await self?.drainDeferredURLs()
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

    // MARK: - Review actions

    /// Approves one proposal, optionally sending the file to another rule.
    /// Returns `true` when the file was moved.
    @discardableResult
    func approve(_ decision: RoutingDecision, as rule: CategoryRule? = nil, batch: UUID? = nil) async -> Bool {
        if isDemoMode {
            pendingDecisions.removeAll { $0.id == decision.id }
            appendEvent(
                SortEvent(
                    fileName: decision.file.name,
                    category: (rule ?? decision.rule)?.name,
                    score: decision.score,
                    outcome: .moved
                ))
            return true
        }
        guard let sorter else { return false }
        do {
            let event = try await sorter.approve(decision, as: rule, batch: batch)
            appendEvent(event)
            pendingDecisions.removeAll { $0.id == decision.id }
            return event.outcome == .moved
        } catch {
            errorMessage = "\(decision.file.name): \(error.localizedDescription)"
            return false
        }
    }

    func reject(_ decision: RoutingDecision) {
        pendingDecisions.removeAll { $0.id == decision.id }
        if !isDemoMode, decision.rule != nil {
            scanMemory.record(for: decision.file, decision: decision, dismissed: true)
            scanMemory.persist()
        }
        appendEvent(
            SortEvent(
                fileName: decision.file.name,
                category: decision.rule?.name,
                score: decision.score,
                outcome: .skipped,
                message: "Kept in place."
            ))
    }

    /// Approves every pending proposal as one undoable step.
    func approveAll(minimumScore: Float = 0) async {
        guard !isApproving else { return }
        let decisions = pendingDecisions.filter { $0.score >= minimumScore }
        guard !decisions.isEmpty else { return }
        isApproving = true
        approvingCount = 0
        approvingTotal = decisions.count
        defer {
            isApproving = false
            approvingCount = 0
            approvingTotal = 0
        }
        let batch = UUID()
        var moved = 0
        var failed = 0
        for decision in decisions {
            approvingCount += 1
            if await approve(decision, batch: batch) { moved += 1 } else { failed += 1 }
        }
        lastBatchMoveCount = moved
        if failed > 0 {
            errorMessage = "\(moved) sorted, \(failed) could not be moved. Details are in Activity."
        } else if moved > 0 {
            notice = "Sorted \(moved) \(moved == 1 ? "file" : "files"). Undo is one click away."
        }
    }

    /// Undoes the whole most recent batch: one sweep, one "Approve all", or
    /// one single move.
    func undoLastMove() async {
        guard !isDemoMode else { return }
        do {
            let batch = try await journal.lastBatch()
            guard !batch.isEmpty else {
                notice = "Nothing to undo."
                return
            }
            let restored = try await journal.undo(batch: batch)
            for entry in batch.prefix(restored) {
                appendEvent(
                    SortEvent(
                        fileName: entry.fileName,
                        category: entry.category,
                        score: entry.score,
                        outcome: .undone
                    ))
            }
            if restored == 0 {
                errorMessage = "These files can no longer be undone. They may have been moved or renamed."
            } else {
                // The files are back in the watched folder. Remember that the
                // user wanted them there, so the next sweep does not move
                // them away again — otherwise "undo" would undo itself.
                let restoredFiles = batch.prefix(restored).compactMap { try? FileSnapshot(url: $0.source) }
                scanMemory.dismiss(files: restoredFiles)
                scanMemory.persist()
                for file in restoredFiles {
                    pendingDecisions.removeAll { $0.file.id == file.id }
                }
                notice = "Put \(restored) \(restored == 1 ? "file" : "files") back."
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
