import Foundation

/// The coarse families of files Sight understands without any model.
///
/// A kind is linked to a rule through the rule's `libraryID`
/// (`CategoryRule.kind`), which is how deterministic evidence such as "this is
/// an `.mp4`" can lift the matching category without the user writing anything.
public enum FileKind: String, CaseIterable, Codable, Sendable {
    case video
    case audio
    case archives
    case code
    case design
    case screenshots
    case photos
    case documents
    case work

    /// Single words that, as a whole rule name, identify a kind. Used so a
    /// rule the user typed by hand ("Movies", "Музыка") still benefits from
    /// deterministic evidence.
    static let synonyms: [String: FileKind] = [
        "video": .video, "videos": .video, "movie": .video, "movies": .video,
        "film": .video, "films": .video, "clips": .video, "видео": .video,
        "фильмы": .video, "ролики": .video,
        "audio": .audio, "music": .audio, "songs": .audio, "sounds": .audio,
        "podcasts": .audio, "музыка": .audio, "аудио": .audio, "звуки": .audio,
        "archive": .archives, "archives": .archives, "installers": .archives,
        "zips": .archives, "backups": .archives, "архивы": .archives,
        "установщики": .archives,
        "code": .code, "dev": .code, "development": .code, "scripts": .code,
        "код": .code, "разработка": .code,
        "design": .design, "designs": .design, "assets": .design,
        "fonts": .design, "дизайн": .design, "шрифты": .design,
        "screenshots": .screenshots, "screenshot": .screenshots,
        "скриншоты": .screenshots, "скрины": .screenshots,
        "photos": .photos, "photo": .photos, "pictures": .photos,
        "images": .photos, "фото": .photos, "фотографии": .photos,
        "картинки": .photos,
        "documents": .documents, "docs": .documents, "study": .documents,
        "документы": .documents, "учёба": .documents, "учеба": .documents,
        "work": .work, "business": .work, "office": .work,
        "работа": .work, "финансы": .work, "finance": .work
    ]

    /// Best guess for a kind from a free-form rule name. Returns `nil` when
    /// the name is ambiguous (two kinds) or unrelated.
    public static func infer(fromRuleName name: String) -> FileKind? {
        let tokens = name
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
        let kinds = Set(tokens.compactMap { synonyms[$0] })
        return kinds.count == 1 ? kinds.first : nil
    }
}

/// Deterministic evidence about a file, produced without any model.
///
/// `boosts` say "this file is very likely of kind X" with a strength in 0…1
/// (1 means certain, e.g. an `.mp4`). `excludes` say "this file cannot be of
/// kind X" (a PDF is never a Video). The semantic layer works inside these
/// bounds, so it can no longer make category mistakes that a file extension
/// rules out.
public struct TypeProfile: Sendable, Equatable {
    public private(set) var boosts: [FileKind: Float] = [:]
    public private(set) var excludes: Set<FileKind> = []
    public private(set) var reasons: [FileKind: String] = [:]

    public static let empty = TypeProfile()

    public init() {}

    public mutating func boost(_ kind: FileKind, _ strength: Float, because reason: String) {
        if strength > (boosts[kind] ?? 0) {
            boosts[kind] = strength
            reasons[kind] = reason
        }
    }

    public mutating func exclude(_ kinds: FileKind...) {
        excludes.formUnion(kinds)
    }

    public var isEmpty: Bool { boosts.isEmpty && excludes.isEmpty }

    /// The strongest deterministic claim, if any.
    public var strongest: (kind: FileKind, strength: Float, reason: String)? {
        guard let best = boosts.max(by: { $0.value < $1.value }) else { return nil }
        return (best.key, best.value, reasons[best.key] ?? "")
    }
}
