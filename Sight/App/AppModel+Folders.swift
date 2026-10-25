import AppKit
import Foundation
import SightCore

extension AppModel {
    func chooseFolder(startingAt directory: URL? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Watch"
        panel.message = "Choose the folder Sight should sort. Subfolders are never entered."
        panel.directoryURL = directory ?? rootURL
        if panel.runModal() == .OK, let url = panel.url {
            setRoot(url)
        }
    }

    func setRoot(_ url: URL) {
        // A folder the app cannot read is worse than no folder at all: the
        // user would watch an empty directory and blame the app for it.
        let scoped = url.startAccessingSecurityScopedResource()
        guard Self.canRead(url) else {
            if scoped { url.stopAccessingSecurityScopedResource() }
            errorMessage = "Sight cannot read “\(url.lastPathComponent)”. Choose it again and allow access."
            return
        }

        stopMonitoring()
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = scoped ? url : nil
        let previousRoot = rootURL
        rootURL = url
        config.rootPath = url.path
        config.rootBookmark = try? BookmarkStore.makeBookmark(for: url)

        // The folders a rule points at have to follow the watched folder,
        // otherwise files end up in a directory the app no longer watches.
        rebasedDestinations(from: previousRoot, to: url)
        saveConfig()

        if rules.isEmpty {
            rules = Self.presetRules(root: url)
            saveRules()
        }

        if modelState.isReady {
            startMonitoring()
            Task {
                try? await self.sorter?.prepare(rules: self.rules)
                await self.refreshFingerprints()
            }
        }
    }

    /// Moves the destinations that belonged to the old watched folder into the
    /// new one. A destination the user pointed somewhere else stays there.
    private func rebasedDestinations(from oldRoot: URL?, to newRoot: URL) {
        guard let oldRoot, oldRoot.standardizedFileURL != newRoot.standardizedFileURL else { return }
        var changed = false
        for index in rules.indices {
            let destination = rules[index].destination
            let parent = destination.deletingLastPathComponent().standardizedFileURL
            guard parent == oldRoot.standardizedFileURL else { continue }
            rules[index].destination = newRoot.appendingPathComponent(
                destination.lastPathComponent,
                isDirectory: true
            )
            changed = true
        }
        if changed { saveRules() }
    }

    /// True when the folder can actually be listed. In the sandbox the answer
    /// is "no" until the user grants access, and the app has to say so
    /// instead of pretending it is watching an empty folder.
    static func canRead(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else { return false }
        return (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil
    }

    func installPresetRules() {
        guard let rootURL else { return }
        rules = Self.presetRules(root: rootURL)
        saveRules()
    }

    /// Watches the user's Downloads folder.
    ///
    /// With the downloads entitlement the folder is already open to the app.
    /// Without it, the open panel is the way in — the user picks the folder
    /// and macOS grants access.
    func useDownloadsFolder() {
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
        guard FileManager.default.fileExists(atPath: downloads.path) else {
            errorMessage = "There is no Downloads folder yet."
            return
        }
        if Self.canRead(downloads) {
            setRoot(downloads)
        } else {
            chooseFolder(startingAt: downloads)
        }
    }

    // MARK: - Curated library

    /// Prompts Sight shipped before the curated library existed. Rules that
    /// still carry one of them are upgraded in place, so an existing setup
    /// gets the better library without losing the user's folders.
    private static let legacyPrompts: [String] = [
        // First version of the built-in rules.
        "contracts, invoices, financial reports",
        "source code, scripts, configuration files",
        "design files, mockups, screenshots, images, fonts",
        "memes, random downloads, temporary screenshots",
        "screenshots, mockups, UI designs of apps",
        "Personal photos and camera images:",
        // Second version of the built-in rules.
        "Work and business documents:",
        "Everyday documents and study materials:",
        "Design and creative assets:",
        "Video files:",
        "Audio files:",
        "Archives and installers:",
        "Code and developer files:",
        // Third version of the built-in rules.
        "work document, office document",
        "document, text document, paper",
        "design file, design asset",
        "screenshot, screen capture",
        "photo, photograph, picture",
        "video file, movie, film",
        "audio file, sound file",
        "archive, compressed archive",
        "source code, code file",
        "junk, clutter, rubbish, trash, garbage, temporary file",
    ]

    private static func isLegacyPrompt(_ prompt: String) -> Bool {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return legacyPrompts.contains { trimmed.hasPrefix($0) }
    }

    /// Brings an existing rule set up to the curated library: known legacy
    /// rules are refreshed in place, missing categories are added. Rules the
    /// user wrote themselves are never touched.
    @discardableResult
    func upgradeRulesToLibrary() -> Bool {
        guard let root = rootURL else { return false }
        var updated = rules
        var changed = false

        for index in updated.indices {
            let rule = updated[index]
            // A rule that came from the library is refreshed with the current
            // prompt and bar — but only while it still carries a prompt Sight
            // wrote. Once the user edits it, it stays theirs. A rule the user
            // wrote is only adopted once, when its prompt is still one of the
            // old built-in ones.
            let template: RuleTemplate?
            if let libraryID = rule.libraryID {
                let candidate = RuleLibrary.all.first { $0.id == libraryID }
                let untouched =
                    candidate.map {
                        rule.prompt == $0.prompt || Self.isLegacyPrompt(rule.prompt)
                    } ?? false
                template = untouched ? candidate : nil
            } else if Self.isLegacyPrompt(rule.prompt),
                let byName = RuleLibrary.template(named: rule.name)
            {
                template = byName
            } else {
                template = nil
            }
            guard let template else { continue }
            if rule.prompt != template.prompt
                || rule.threshold != template.confidence
                || rule.libraryID != template.id
            {
                updated[index].prompt = template.prompt
                updated[index].threshold = template.confidence
                updated[index].libraryID = template.id
                // "Junk" is a category no embedding can judge reliably: it
                // swallows real files. It ships switched off and stays
                // switched off when an older setup is upgraded.
                if template.id == "junk", rule.libraryID == nil {
                    updated[index].isEnabled = false
                }
                changed = true
            }
        }

        for template in RuleLibrary.starterRules {
            guard !updated.contains(where: { $0.libraryID == template.id || $0.name == template.name })
            else { continue }
            var rule = template.rule(root: root)
            if template.id == "junk" { rule.isEnabled = false }
            updated.append(rule)
            changed = true
        }

        if changed {
            rules = updated
            saveRules()
            Task {
                try? await self.sorter?.prepare(rules: self.rules)
                await self.refreshFingerprints()
            }
        }
        return changed
    }

    /// Replaces every library rule with the current curated version and
    /// adds the categories that are missing. Custom rules are kept.
    func restoreCuratedLibrary() {
        guard let root = rootURL else { return }
        // Legacy built-ins are adopted first, so they are replaced instead of
        // duplicated. A rule the user wrote keeps its own name and prompt.
        _ = upgradeRulesToLibrary()
        var updated = rules.filter { $0.libraryID == nil }
        for template in RuleLibrary.starterRules {
            var rule = template.rule(root: root)
            if template.id == "junk" { rule.isEnabled = false }
            updated.append(rule)
        }
        rules = updated
        saveRules()
        Task {
            try? await self.sorter?.prepare(rules: self.rules)
            await self.refreshFingerprints()
        }
    }

    // MARK: - Reset

    /// Forgets everything: rules, history, remembered decisions and the
    /// chosen folder. The app returns to the onboarding flow. The downloaded
    /// model stays on disk — it is a download, not a memory.
    func startOver() async {
        stopMonitoring()
        rules = []
        events = []
        pendingDecisions = []
        lastSummary = nil
        ruleFingerprints = [:]

        try? await ruleStore.save([])
        try? await journal.clear()
        scanMemory.reset()
        examples.reset()

        var fresh = SightConfig()
        fresh.theme = config.theme
        fresh.dimension = config.dimension
        fresh.loadVision = config.loadVision
        fresh.loadAudio = config.loadAudio
        config = fresh
        saveConfig()

        rootURL = nil
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    @discardableResult
    func addRule(name: String, prompt: String, destination: URL, threshold: Float? = nil) -> CategoryRule? {
        let rule = CategoryRule(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination,
            threshold: threshold
        )
        guard rule.isValid else { return nil }
        rules.append(rule)
        saveRules()
        Task {
            try? await self.sorter?.prepare(rules: self.rules)
            await self.refreshFingerprints()
        }
        return rule
    }

    func updateRule(_ updated: CategoryRule) {
        guard let index = rules.firstIndex(where: { $0.id == updated.id }) else { return }
        rules[index] = updated
        saveRules()
        Task {
            try? await self.sorter?.prepare(rules: self.rules)
            await self.refreshFingerprints()
        }
    }

    func deleteRule(id: UUID) {
        rules.removeAll { $0.id == id }
        ruleFingerprints[id] = nil
        saveRules()
        Task {
            try? await self.sorter?.prepare(rules: self.rules)
            await self.refreshFingerprints()
        }
    }

    func makeDestination(named name: String) -> URL {
        let base = rootURL ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent(name, isDirectory: true)
    }

    /// A tidy folder name derived from a rule name: "Side project files" →
    /// "Side project files", with path-hostile characters collapsed.
    static func folderName(from ruleName: String) -> String {
        let cleaned =
            ruleName
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: " ")
        let collapsed =
            cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let trimmed = collapsed.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Unsorted" : trimmed
    }

    private static func presetRules(root: URL) -> [CategoryRule] {
        RuleLibrary.starterRules.map { template in
            var rule = template.rule(root: root)
            if template.id == "junk" {
                // Clutter folding is opt-in: wrong "junk" calls are the most
                // annoying kind of mistake, so it ships switched off.
                rule.isEnabled = false
            }
            return rule
        }
    }
}
