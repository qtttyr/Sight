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
    /// Bumped when the meaning of a stored value changes, so old files are
    /// migrated instead of silently misread.
    public static let currentSchemaVersion = 3

    public var schemaVersion: Int
    public var rootPath: String?
    public var rootBookmark: Data?
    public var mode: SortMode
    public var dimension: EmbeddingDimension
    /// How sure Sight must be, as a probability, before it moves a file
    /// without asking. Everything below this still gets a proposal in Review.
    public var confidence: Float
    public var theme: ThemeMode
    public var loadVision: Bool
    public var loadAudio: Bool
    public var hasCompletedOnboarding: Bool
    public var autoSortEnabled: Bool
    /// Give files with meaningless names a clear one when they are sorted.
    public var renameFiles: Bool
    /// Propose (or, in Auto mode, create) a new folder when many files fit
    /// no existing category but clearly belong together.
    public var suggestFolders: Bool
    /// Folder suggestions the user declined; never offered again.
    public var dismissedFolders: [String]

    public static let defaultConfidence: Float = 0.62
    public static let confidenceRange: ClosedRange<Float> = 0.35...0.95

    public init(
        rootPath: String? = nil,
        rootBookmark: Data? = nil,
        mode: SortMode = .review,
        dimension: EmbeddingDimension = .full,
        confidence: Float = SightConfig.defaultConfidence,
        theme: ThemeMode = .system,
        loadVision: Bool = true,
        loadAudio: Bool = false,
        hasCompletedOnboarding: Bool = false,
        autoSortEnabled: Bool = false,
        renameFiles: Bool = true,
        suggestFolders: Bool = true,
        dismissedFolders: [String] = []
    ) {
        self.renameFiles = renameFiles
        self.suggestFolders = suggestFolders
        self.dismissedFolders = dismissedFolders
        self.schemaVersion = Self.currentSchemaVersion
        self.rootPath = rootPath
        self.rootBookmark = rootBookmark
        self.mode = mode
        self.dimension = dimension
        self.confidence = confidence
        self.theme = theme
        self.loadVision = loadVision
        self.loadAudio = loadAudio
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.autoSortEnabled = autoSortEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, rootPath, rootBookmark, mode, dimension, confidence
        case theme, loadVision, loadAudio, hasCompletedOnboarding, autoSortEnabled
        case renameFiles, suggestFolders, dismissedFolders
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        schemaVersion = Self.currentSchemaVersion
        rootPath = try container.decodeIfPresent(String.self, forKey: .rootPath)
        rootBookmark = try container.decodeIfPresent(Data.self, forKey: .rootBookmark)
        mode = try container.decodeIfPresent(SortMode.self, forKey: .mode) ?? .review
        theme = try container.decodeIfPresent(ThemeMode.self, forKey: .theme) ?? .system
        loadVision = try container.decodeIfPresent(Bool.self, forKey: .loadVision) ?? true
        loadAudio = try container.decodeIfPresent(Bool.self, forKey: .loadAudio) ?? false
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        autoSortEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoSortEnabled) ?? false
        renameFiles = try container.decodeIfPresent(Bool.self, forKey: .renameFiles) ?? true
        suggestFolders = try container.decodeIfPresent(Bool.self, forKey: .suggestFolders) ?? true
        dismissedFolders = try container.decodeIfPresent([String].self, forKey: .dismissedFolders) ?? []

        if storedVersion < 3 {
            // Earlier versions stored a relative-gap "confidence" and a raw
            // similarity threshold and truncated embeddings to save time that
            // was never saved. Neither number means anything now, so they
            // are replaced by the calibrated defaults.
            confidence = Self.defaultConfidence
            dimension = .full
        } else {
            let stored = try container.decodeIfPresent(Float.self, forKey: .confidence) ?? Self.defaultConfidence
            confidence = min(max(stored, Self.confidenceRange.lowerBound), Self.confidenceRange.upperBound)
            dimension = try container.decodeIfPresent(EmbeddingDimension.self, forKey: .dimension) ?? .full
        }
    }
}
