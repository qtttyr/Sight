import Foundation
import SightCore

extension AppModel {
    func loadModel() async {
        guard !isModelLoading else { return }
        isModelLoading = true
        defer { isModelLoading = false }

        let bundle = AppPaths.modelDirectory.appendingPathComponent("model", isDirectory: true)
        guard FileManager.default.fileExists(atPath: bundle.appendingPathComponent("config.json").path) else {
            modelState = .notInstalled
            return
        }

        modelState = .loading("Preparing your local model…")
        do {
            let provider = CoreAIEmbeddingProvider(
                bundleURL: bundle,
                loadVision: config.loadVision,
                loadAudio: config.loadAudio
            )
            try await provider.prepare()
            let sorter = Sorter(provider: provider, journal: journal, examples: examples)
            try await sorter.prepare(rules: rules)

            self.provider = provider
            self.sorter = sorter
            self.modelState = .ready
            self.modelDiskUsage = await modelStore.diskUsage()

            // Bring an existing setup up to the curated library before the
            // rules are embedded, so old prompts never survive a launch.
            if upgradeRulesToLibrary() {
                try? await sorter.prepare(rules: self.rules)
            }

            await refreshFingerprints()
            startMonitoring()
            #if DEBUG
                if Evaluation.isBenchmarkEnabled {
                    await Evaluation.runBenchmark(model: self)
                    exit(0)
                }
                if Evaluation.isEnabled {
                    await Evaluation.run(model: self)
                }
            #endif
        } catch {
            self.modelState = .failed(error.localizedDescription)
        }
    }

    func downloadModel() async {
        guard !isDemoMode else { return }
        guard !isDownloadingModel, !isModelLoading else { return }
        isDownloadingModel = true
        defer { isDownloadingModel = false }

        modelState = .downloading(0, "Starting download…")
        do {
            try await modelStore.download(assets: modelAssets) { [weak self] update in
                Task { @MainActor [weak self] in
                    self?.modelState = .downloading(update.fraction, update.currentFile)
                }
            }
            modelState = .loading("Preparing your local model…")
            await loadModel()
            modelDiskUsage = await modelStore.diskUsage()
        } catch {
            modelState = .failed(error.localizedDescription)
        }
    }

    func refreshFingerprints() async {
        guard !isDemoMode else { return }
        guard let sorter else {
            ruleFingerprints = [:]
            return
        }
        var fingerprints: [UUID: [Float]] = [:]
        for rule in rules {
            let values = await sorter.fingerprint(for: rule, dimension: config.dimension)
            if !values.isEmpty {
                fingerprints[rule.id] = values
            }
        }
        ruleFingerprints = fingerprints
    }

    func reloadModelForAssetChanges() async {
        guard !isDemoMode else { return }
        guard await modelStore.isInstalled(modelAssets) else {
            modelState = .notInstalled
            return
        }
        provider = nil
        sorter = nil
        await loadModel()
    }
}
