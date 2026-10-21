import Foundation

public enum ThemeMode: String, Codable, CaseIterable, Sendable {
    case system
    case dark
    case light
}

public enum SortMode: String, Codable, CaseIterable, Sendable {
    case review
    case auto
}

public enum EmbeddingDimension: Int, Codable, CaseIterable, Sendable {
    case full = 768
    case balanced = 512
    case compact = 256
    case tiny = 128

    public var label: String {
        switch self {
        case .full: "768"
        case .balanced: "512"
        case .compact: "256"
        case .tiny: "128"
        }
    }
}

/// The user's persisted preferences.
public struct SightConfig: Codable, Sendable, Equatable {
    public var rootPath: String?
    public var rootBookmark: Data?
    public var mode: SortMode
    public var dimension: EmbeddingDimension
    public var threshold: Float
    public var margin: Float
    public var theme: ThemeMode
    public var loadVision: Bool
    public var loadAudio: Bool
    public var hasCompletedOnboarding: Bool
    public var autoSortEnabled: Bool

    public init(
        rootPath: String? = nil,
        rootBookmark: Data? = nil,
        mode: SortMode = .review,
        dimension: EmbeddingDimension = .compact,
        threshold: Float = 0.35,
        margin: Float = 0.035,
        theme: ThemeMode = .system,
        loadVision: Bool = true,
        loadAudio: Bool = false,
        hasCompletedOnboarding: Bool = false,
        autoSortEnabled: Bool = false
    ) {
        self.rootPath = rootPath
        self.rootBookmark = rootBookmark
        self.mode = mode
        self.dimension = dimension
        self.threshold = threshold
        self.margin = margin
        self.theme = theme
        self.loadVision = loadVision
        self.loadAudio = loadAudio
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.autoSortEnabled = autoSortEnabled
    }
}
