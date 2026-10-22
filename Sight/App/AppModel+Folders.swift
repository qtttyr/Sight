import AppKit
import Foundation
import SightCore

extension AppModel {
    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Watch"
        panel.message = "Choose the folder Sight should sort. Subfolders are never entered."
        panel.directoryURL = rootURL
        if panel.runModal() == .OK, let url = panel.url {
            setRoot(url)
        }
    }

    func setRoot(_ url: URL) {
        stopMonitoring()
        securityScopedURL?.stopAccessingSecurityScopedResource()
        _ = url.startAccessingSecurityScopedResource()
        securityScopedURL = url
        rootURL = url
        config.rootPath = url.path
        config.rootBookmark = try? BookmarkStore.makeBookmark(for: url)
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

    func installPresetRules() {
        guard let rootURL else { return }
        rules = Self.presetRules(root: rootURL)
        saveRules()
    }

    func addRule(name: String, prompt: String, destination: URL, threshold: Float? = nil) {
        let rule = CategoryRule(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination,
            threshold: threshold
        )
        guard rule.isValid else { return }
        rules.append(rule)
        saveRules()
        Task {
            try? await self.sorter?.prepare(rules: self.rules)
            await self.refreshFingerprints()
        }
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
        let cleaned = ruleName
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: " ")
        let collapsed = cleaned
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
