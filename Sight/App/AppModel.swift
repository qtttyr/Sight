import AppKit
import Observation
import SightCore
import SwiftUI

enum ModelState: Equatable {
    case checking
    case notInstalled
    case downloading(Double, String)
    case loading(String)
    case ready
    case failed(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .loading: true
        default: false
        }
    }

    var title: String {
        switch self {
        case .checking: "CHECKING"
        case .notInstalled: "MODEL MISSING"
        case .downloading: "DOWNLOADING"
        case .loading: "PREPARING"
        case .ready: "MODEL READY"
        case .failed: "MODEL ERROR"
        }
    }
}

@MainActor
@Observable
final class AppModel {
    var section: AppSection = .live
    var config = SightConfig()
    var rules: [CategoryRule] = []
    var events: [SortEvent] = []
    var pendingDecisions: [RoutingDecision] = []
    var modelState: ModelState = .checking
    var isBootstrapping = true
    var isSweeping = false
    var sortProgress: SortProgress?
    var lastSummary: SortSummary?
    var errorMessage: String?
    var rootURL: URL?
    var ruleFingerprints: [UUID: [Float]] = [:]
    var modelDiskUsage: Int64 = 0
    var testDecision: RoutingDecision?
    var isShowingRuleEditor = false
    var isShowingReview = false

    @ObservationIgnored let configStore = ConfigStore()
    @ObservationIgnored let ruleStore = RuleStore()
    @ObservationIgnored let modelStore = ModelStore()
    @ObservationIgnored let journal = Journal(url: AppPaths.journalURL)

    @ObservationIgnored var provider: CoreAIEmbeddingProvider?
    @ObservationIgnored var sorter: Sorter?
    @ObservationIgnored var monitor: FSEventsMonitor?
    @ObservationIgnored var securityScopedURL: URL?

    private var didBootstrap = false
    @ObservationIgnored var isModelLoading = false
    @ObservationIgnored var isDownloadingModel = false
    @ObservationIgnored var isDemoMode = false

    var modelAssets: Set<ModelAsset> {
        var assets: Set<ModelAsset> = [.text]
        if config.loadVision { assets.insert(.vision) }
        if config.loadAudio { assets.insert(.audio) }
        return assets
    }

    var modelSizeBytes: Int64 {
        ModelManifest.totalBytes(for: modelAssets)
    }

    var formattedModelSize: String {
        ByteCountFormatter.string(fromByteCount: modelSizeBytes, countStyle: .file)
    }

    var rootDisplayPath: String {
        guard let rootURL else { return "NO FOLDER" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if rootURL.path.hasPrefix(home) {
            return "~" + rootURL.path.dropFirst(home.count)
        }
        return rootURL.path
    }

    var isAutoMode: Bool {
        config.mode == .auto && config.autoSortEnabled
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        defer { isBootstrapping = false }

        #if DEBUG
        if DemoMode.isEnabled {
            DemoMode.configure(self)
            return
        }
        #endif

        do {
            try AppPaths.ensureDirectories()
            config = try await configStore.load()
            rules = try await ruleStore.load()
            restoreFolderAccess()
            events = ((try? await journal.recent(limit: 30)) ?? []).map { entry in
                SortEvent(
                    date: entry.date,
                    fileName: entry.fileName,
                    category: entry.category,
                    score: entry.score,
                    outcome: .moved
                )
            }
            modelDiskUsage = await modelStore.diskUsage()

            if await modelStore.isInstalled(modelAssets) {
                modelState = .loading("Preparing your local model…")
                Task { await self.loadModel() }
            } else {
                modelState = .notInstalled
            }

            if config.hasCompletedOnboarding, rootURL != nil {
                startMonitoring()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveConfig() {
        guard !isDemoMode else { return }
        let snapshot = config
        Task { try? await configStore.save(snapshot) }
    }

    func saveRules() {
        guard !isDemoMode else { return }
        let snapshot = rules
        Task { try? await ruleStore.save(snapshot) }
    }

    func setTheme(_ mode: ThemeMode) {
        config.theme = mode
        saveConfig()
    }

    func clearError() {
        errorMessage = nil
    }

    func revealModelFolder() {
        try? AppPaths.ensureDirectories()
        NSWorkspace.shared.activateFileViewerSelecting([AppPaths.modelDirectory])
    }

    func purgeModel() {
        guard !isDemoMode else { return }
        Task {
            try? await self.modelStore.remove()
            self.provider = nil
            self.sorter = nil
            self.modelState = .notInstalled
            self.modelDiskUsage = 0
            self.stopMonitoring()
        }
    }

    private func restoreFolderAccess() {
        if let data = config.rootBookmark, let resolved = try? BookmarkStore.resolve(data) {
            if resolved.isStale, let fresh = try? BookmarkStore.makeBookmark(for: resolved.url) {
                config.rootBookmark = fresh
                saveConfig()
            }
            _ = resolved.url.startAccessingSecurityScopedResource()
            securityScopedURL = resolved.url
            rootURL = resolved.url
        } else if let path = config.rootPath {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                rootURL = url
            }
        }
    }
}
