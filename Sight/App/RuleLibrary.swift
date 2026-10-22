import Foundation
import SightCore

/// The curated rule library. Each template carries a tuned prompt — a rich,
/// natural-language description of everything that belongs in the folder —
/// plus a per-rule confidence threshold tuned empirically for that kind of
/// content. Distinctive types (video, audio, archives) sit well above their
/// threshold, so they accept aggressively; fuzzy types (Work, Documents) run
/// more conservatively.
struct RuleTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let prompt: String
    let threshold: Float
    /// One-line explanation shown in the library, so the user knows what a
    /// rule is going to catch before enabling it.
    let catches: String

    func rule(root: URL) -> CategoryRule {
        CategoryRule(
            name: name,
            prompt: prompt,
            destination: root.appendingPathComponent(name, isDirectory: true),
            threshold: threshold
        )
    }
}

enum RuleLibrary {
    /// Starter set installed when a root is chosen for the first time.
    /// Covers the practical floor of a real Downloads folder: document
    /// formats, media, archives, code — by structure, not hope.
    static let starterRules: [RuleTemplate] = [
        work, documents, design, photos, video, audio, archives, code, junk
    ]

    // MARK: - Semantic categories

    static let work = RuleTemplate(
        id: "work",
        name: "Work",
        prompt: """
        Work and business documents: contracts, agreements, NDAs, invoices, bills,
        receipts, quotations, purchase orders, bank statements, tax forms, spreadsheets
        and budgets, resumes, CVs, cover letters, job applications, business
        correspondence, project briefs, task lists for the office, meeting agendas,
        company reports, presentations and slide decks for work
        """,
        threshold: 0.33,
        catches: "Contracts, invoices, resumes, decks — the office paper trail."
    )

    static let documents = RuleTemplate(
        id: "documents",
        name: "Documents",
        prompt: """
        Everyday documents and study materials: lecture files, textbooks, manuals,
        guides, documentation exports, course materials, homework and assignments,
        printable forms, government paperwork, application forms, personal letters,
        essays, theses, article drafts, research papers, general pdf documents that
        are not work-related
        """,
        threshold: 0.33,
        catches: "Study material, manuals, forms, general PDFs and paperwork."
    )

    static let design = RuleTemplate(
        id: "design",
        name: "Design",
        prompt: """
        Design and creative assets: UI mockups, app screenshots, interface designs,
        wireframes, prototypes, logos, icons, brand kits, style guides, banners and
        marketing visuals, illustrations, posters, digital art, figma and sketch
        exports, photoshop and illustrator files, typefaces and fonts, palette and
        color references
        """,
        threshold: 0.32,
        catches: "Mockups, screenshots, logos, art, fonts, visual references."
    )

    static let photos = RuleTemplate(
        id: "photos",
        name: "Photos",
        prompt: """
        Personal photos and camera images: photos taken on a phone or camera,
        portraits and selfies, pictures of people, pets, landscapes and travel,
        photo set exports, wallpapers and backgrounds, memes and funny pictures,
        event photography, snapshots of everyday moments
        """,
        threshold: 0.30,
        catches: "Camera shots, wallpapers, memes, personal pictures."
    )

    static let video = RuleTemplate(
        id: "video",
        name: "Video",
        prompt: """
        Video files: movies, films, tv episodes, screen recordings and screencasts,
        tutorials and how-to videos, game clips and replays, animations, video
        exports from editors, mp4 mkv mov webm clips, footage filmed for social
        media, video recordings of presentations
        """,
        threshold: 0.28,
        catches: "Movies, screen recordings, clips, exported footage."
    )

    static let audio = RuleTemplate(
        id: "audio",
        name: "Audio",
        prompt: """
        Audio files: music tracks and albums, songs, mp3 and wav files, voice memos
        and recordings, meeting recordings, podcasts and podcast episodes,
        audiobooks, sound effects and samples, jingles, mixing stems, audio exports
        from editors
        """,
        threshold: 0.28,
        catches: "Music, voice memos, podcasts, samples, meeting recordings."
    )

    static let archives = RuleTemplate(
        id: "archives",
        name: "Archives",
        prompt: """
        Archives and installers: zip archives, tarballs, gz and tgz packages, rar
        files, dmg disk images, pkg installers, application installers downloaded
        from the internet, packed libraries and releases, backup archives, anything
        that needs unpacking or installing after downloading
        """,
        threshold: 0.28,
        catches: "ZIP/tgz/DMG/PKG — stuff that unpacks or installs."
    )

    static let code = RuleTemplate(
        id: "code",
        name: "Code",
        prompt: """
        Code and developer files: source code, scripts, repositories, terminal logs,
        json yaml toml configuration, sql queries, css and style sheets, swift
        python javascript typescript go rust sources, docker files, api responses,
        error traces, build outputs, libraries, command line utilities
        """,
        threshold: 0.28,
        catches: "Sources, scripts, configs, logs, dev tooling."
    )

    static let junk = RuleTemplate(
        id: "junk",
        name: "Junk",
        prompt: """
        Obvious clutter worth deleting: random temporary downloads, duplicate files,
        cache copies, one-off test images, broken downloads, leftovers that carry
        no personal, professional or creative value
        """,
        threshold: 0.34,
        catches: "Doubles, temp leftovers, throwaway clutter."
    )

    /// Everything the library offers.
    static var all: [RuleTemplate] {
        [work, documents, design, photos, video, audio, archives, code, junk]
    }

    static func template(named name: String) -> RuleTemplate? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}
