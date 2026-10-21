import Foundation

public enum ModelAsset: String, CaseIterable, Codable, Sendable {
    case text
    case vision
    case audio

    public var displayName: String {
        switch self {
        case .text: "Text + code"
        case .vision: "Images"
        case .audio: "Audio"
        }
    }
}

public struct ModelFile: Hashable, Sendable {
    public let path: String
    public let size: Int64
    public let sha256: String
    public let asset: ModelAsset?

    public init(path: String, size: Int64, sha256: String, asset: ModelAsset? = nil) {
        self.path = path
        self.size = size
        self.sha256 = sha256
        self.asset = asset
    }
}

public enum ModelManifest {
    /// Pinned to a known revision of the Apache-2.0 Core AI conversion. Never
    /// use `main` here: a model update must be an explicit, reviewable change.
    public static let repository = "EverPaper/embeddinggemma-2-coreai"
    public static let revision = "305fc2a96790d9343f38038aeca211dfca56d9a5"
    public static let baseURL = "https://huggingface.co/\(repository)/resolve/\(revision)"

    public static let sharedFiles: [ModelFile] = [
        ModelFile(path: "model/config.json", size: 4_643, sha256: "0204c8d4532f6930709c3c8eb7f7b25b54e4be42aa7b8c6c397fc17e872fb7bf"),
        ModelFile(path: "model/MODEL-ATTRIBUTION.json", size: 5_166, sha256: "7951556c4559c8609cf67715acc53e58d8c70f7f62242494d7858406b1bbe2f7"),
        ModelFile(path: "model/tokenizer/tokenizer.json", size: 32_170_510, sha256: "4d777ef5bdc1aa36227abdfb77c3e49e7b9c892d16e1b6bda41c393504828be4"),
        ModelFile(path: "model/tokenizer/tokenizer_config.json", size: 1_599, sha256: "17bd5d6e9364ca49a534e1502076593317c298d4a663623091ed45388f004874")
    ]

    public static let textFiles: [ModelFile] = [
        ModelFile(path: "model/embeddinggemma-2-text-mm.aimodel/main.hash", size: 32, sha256: "ea089710e57b22972d6ab4d4b960b385394b81f333ba2f75b4fb4aac1d238e6f", asset: .text),
        ModelFile(path: "model/embeddinggemma-2-text-mm.aimodel/main.mlirb", size: 632_206_233, sha256: "0b51638f2d17794825de21def6ab485d968fdf412853ea209617623a51f1bbde", asset: .text),
        ModelFile(path: "model/embeddinggemma-2-text-mm.aimodel/metadata.json", size: 431, sha256: "8984123cfdb32ba8cf526a1f3a41571205475aff40b3f1d65494f476f115f8a6", asset: .text)
    ]

    public static let visionFiles: [ModelFile] = [
        ModelFile(path: "model/embeddinggemma-2-vision.aimodel/main.hash", size: 32, sha256: "ce93c518c185454be41b493738f9ab3d5b662dd0306d1007cd4e12ad4c0baaa5", asset: .vision),
        ModelFile(path: "model/embeddinggemma-2-vision.aimodel/main.mlirb", size: 307_025_240, sha256: "01e50a398ae9e003fd6bb5f1c74544032474394912b7c7396965f98b15423f19", asset: .vision),
        ModelFile(path: "model/embeddinggemma-2-vision.aimodel/metadata.json", size: 389, sha256: "45bb764a8df5e1b2a6ef4260d4dd006a57dc7af4f408f07ed2976022cd39390c", asset: .vision)
    ]

    public static let audioFiles: [ModelFile] = [
        ModelFile(path: "model/embeddinggemma-2-audio.aimodel/main.hash", size: 32, sha256: "e8e6db4dcacc0a21bbc0b981420753b44ab561c516a673fe5e9db986c7266b78", asset: .audio),
        ModelFile(path: "model/embeddinggemma-2-audio.aimodel/main.mlirb", size: 589_332_135, sha256: "9ca590b09b327f7a8cae94ccace30d151621ae57a4a3f2a8b654145bc1df95f8", asset: .audio),
        ModelFile(path: "model/embeddinggemma-2-audio.aimodel/metadata.json", size: 403, sha256: "dc64e3f52ce6778c0c9e5f58157f328a9f081b21deb5eca74e333fcd4b8f15f6", asset: .audio)
    ]

    public static func files(for assets: Set<ModelAsset>) -> [ModelFile] {
        var files = sharedFiles
        if assets.contains(.text) { files += textFiles }
        if assets.contains(.vision) { files += visionFiles }
        if assets.contains(.audio) { files += audioFiles }
        return files
    }

    public static func totalBytes(for assets: Set<ModelAsset>) -> Int64 {
        files(for: assets).reduce(0) { $0 + $1.size }
    }
}
