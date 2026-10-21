import Foundation
import SightCore

/// Thin adapter between SightCore's embedding protocol and the vendored
/// EmbeddingGemma 2 Core AI implementation. The actor serializes inference so
/// the Core AI functions are never re-entered.
actor CoreAIEmbeddingProvider: EmbeddingProviding {
    nonisolated let dimension = 768

    private let bundleURL: URL
    private var loadVision: Bool
    private var loadAudio: Bool
    private var model: EmbeddingGemma2?

    init(bundleURL: URL, loadVision: Bool, loadAudio: Bool) {
        self.bundleURL = bundleURL
        self.loadVision = loadVision
        self.loadAudio = loadAudio
    }

    func prepare() async throws {
        guard model == nil else { return }
        let loaded = try await EmbeddingGemma2(
            bundle: bundleURL,
            compute: .neuralEngine,
            loadVision: loadVision,
            imageCompute: .neuralEngine,
            loadAudio: loadAudio,
            audioCompute: .neuralEngine
        )
        _ = try await loaded.prewarm()
        model = loaded
    }

    func reconfigure(loadVision: Bool, loadAudio: Bool) async throws {
        guard self.loadVision != loadVision || self.loadAudio != loadAudio else { return }
        self.loadVision = loadVision
        self.loadAudio = loadAudio
        self.model = nil
        try await prepare()
    }

    func embed(text: String, kind: EmbeddingKind) async throws -> [Float] {
        guard let model else { throw EmbeddingError.modelUnavailable }
        do {
            return try await model.embed(text, kind: kind.rawValue, dim: 768)
        } catch {
            throw EmbeddingError.underlying(error.localizedDescription)
        }
    }

    func embed(imageAt url: URL) async throws -> [Float] {
        guard let model else { throw EmbeddingError.modelUnavailable }
        guard model.hasVision else {
            throw EmbeddingError.unsupportedModality("Images are disabled in Settings.")
        }
        do {
            return try await model.embedImage(url: url, applyEXIFOrientation: true, dim: 768)
        } catch {
            throw EmbeddingError.underlying(error.localizedDescription)
        }
    }
}
