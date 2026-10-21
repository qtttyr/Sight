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

    func addRule(name: String, prompt: String, destination: URL) {
        let rule = CategoryRule(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination
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

    private static func presetRules(root: URL) -> [CategoryRule] {
        [
            CategoryRule(
                name: "Work",
                prompt: "contracts, invoices, financial reports, spreadsheets, resumes, NDAs, presentations, business documents",
                destination: root.appendingPathComponent("Work", isDirectory: true)
            ),
            CategoryRule(
                name: "Code",
                prompt: "source code, scripts, configuration files, repositories, JSON, Swift, Python, JavaScript, terminal logs",
                destination: root.appendingPathComponent("Code", isDirectory: true)
            ),
            CategoryRule(
                name: "Design",
                prompt: "design files, mockups, screenshots, images, fonts, UI assets, product photos, visual references",
                destination: root.appendingPathComponent("Design", isDirectory: true)
            ),
            CategoryRule(
                name: "Junk",
                prompt: "memes, random downloads, temporary screenshots, duplicates, installers, archives, graphical clutter",
                destination: root.appendingPathComponent("Junk", isDirectory: true)
            )
        ]
    }
}
