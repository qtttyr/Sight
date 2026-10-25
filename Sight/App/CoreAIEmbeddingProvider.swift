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
            // The fast preparation is several times quicker and the model
            // cannot tell the difference. If anything about a picture trips
            // it up, the exact vendored path takes over.
            let inputs = try ImagePreparation.inputs(for: url)
            return try await model.embedImage(inputs, dim: 768)
        } catch {
            do {
                return try await model.embedImage(url: url, applyEXIFOrientation: true, dim: 768)
            } catch {
                throw EmbeddingError.underlying(error.localizedDescription)
            }
        }
    }

    /// Embeds a picture with the vendored, bit-exact preparation. Kept for
    /// the profiler: it is the yardstick the fast path is measured against.
    func embedExact(imageAt url: URL) async throws -> [Float] {
        guard let model else { throw EmbeddingError.modelUnavailable }
        guard model.hasVision else {
            throw EmbeddingError.unsupportedModality("Images are disabled in Settings.")
        }
        return try await model.embedImage(url: url, applyEXIFOrientation: true, dim: 768)
    }

    /// Embeds a picture that is already prepared for the vision tower.
    func embed(prepared inputs: VisionInputs) async throws -> [Float] {
        guard let model else { throw EmbeddingError.modelUnavailable }
        guard model.hasVision else {
            throw EmbeddingError.unsupportedModality("Images are disabled in Settings.")
        }
        do {
            return try await model.embedImage(inputs, dim: 768)
        } catch {
            throw EmbeddingError.underlying(error.localizedDescription)
        }
    }
}
