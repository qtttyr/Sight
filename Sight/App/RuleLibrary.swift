import Foundation
import SightCore

/// The curated rule library.
///
/// Two things make a rule work in practice:
///
/// 1. **Separate, concrete ideas.** Sight splits a prompt at every comma and
///    embeds each idea on its own, then asks "which of this rule's ideas does
///    the file match best?". Short natural descriptions of *what the content
///    is* ("invoice or receipt for a purchase") separate far better than
///    single keywords or one long run-on sentence.
/// 2. **A per-rule bar.** Broad categories (work) need to be surer than
///    distinctive ones before Sight moves a file on its own.
///
/// File types, name conventions and image metadata are handled by
/// `TypeAnalyzer` and attach to these rules through their id, so renaming a
/// rule or changing its folder never breaks the deterministic part.
struct RuleTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let prompt: String
    /// Minimum probability before Sight may move a file with this rule on its
    /// own. `nil` follows the global setting.
    let confidence: Float?
    /// One-line explanation shown in the library, so the user knows what a
    /// rule is going to catch before enabling it.
    let catches: String

    func rule(root: URL) -> CategoryRule {
        CategoryRule(
            name: name,
            prompt: prompt,
            destination: root.appendingPathComponent(name, isDirectory: true),
            threshold: confidence,
            libraryID: id
        )
    }
}

enum RuleLibrary {
    /// Starter set installed when a root is chosen for the first time.
    static let starterRules: [RuleTemplate] = [
        work, documents, design, screenshots, photos, video, audio, archives, code, junk,
    ]

    /// Everything the library offers.
    static var all: [RuleTemplate] { starterRules }

    static func template(named name: String) -> RuleTemplate? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    // MARK: - Semantic categories

    static let work = RuleTemplate(
        id: "work",
        name: "Work",
        prompt: """
            invoice or receipt for a purchase, signed contract or agreement, \
            non-disclosure agreement, bank statement or tax return, \
            payroll slip or salary statement, business proposal or price quotation, \
            resume or CV, cover letter or job application, \
            business meeting minutes or project brief, company report or business presentation, \
            budget or financial spreadsheet, purchase order or shipping document
            """,
        confidence: nil,
        catches: "Contracts, invoices, resumes, decks — the office paper trail."
    )

    static let documents = RuleTemplate(
        id: "documents",
        name: "Documents",
        prompt: """
            lecture notes or study material, student worksheet or homework assignment, \
            essay or article draft, textbook chapter or course reading, \
            user manual or how-to guide, personal letter or diary entry, \
            official form or application, academic paper or thesis, \
            news article or story text, class timetable or schedule
            """,
        confidence: nil,
        catches: "Study material, notes, essays, manuals, general paperwork."
    )

    static let design = RuleTemplate(
        id: "design",
        name: "Design",
        prompt: """
            logo or icon design, user interface mockup or wireframe, \
            illustration or digital artwork, poster or banner or flyer, \
            brand guidelines or brand kit, font or typeface file, \
            vector graphic, 3D model or render, pixel art or sprite sheet, \
            color palette or moodboard, texture or background pattern
            """,
        confidence: nil,
        catches: "Mockups, logos, icons, fonts, brand and art references."
    )

    static let screenshots = RuleTemplate(
        id: "screenshots",
        name: "Screenshots",
        prompt: """
            screenshot of a phone app, screenshot of a website or browser window, \
            screen capture of a computer desktop, screenshot of a chat conversation, \
            screenshot of an error message, captured user interface
            """,
        confidence: nil,
        catches: "Screen captures — anything macOS or iOS captured from a screen."
    )

    static let photos = RuleTemplate(
        id: "photos",
        name: "Photos",
        prompt: """
            personal photo of people, photo of a landscape or travel destination, \
            picture of a pet or animal, selfie or portrait, family photo, \
            photo of food, camera picture, meme or funny image, \
            wallpaper or background picture, animated gif reaction
            """,
        confidence: nil,
        catches: "Camera shots, wallpapers, memes, personal pictures."
    )

    static let video = RuleTemplate(
        id: "video",
        name: "Video",
        prompt: """
            video clip or movie, tv series episode, screen recording, \
            tutorial video, camera footage, animation, short video
            """,
        confidence: nil,
        catches: "Movies, screen recordings, clips, exported footage."
    )

    static let audio = RuleTemplate(
        id: "audio",
        name: "Audio",
        prompt: """
            music track or song, podcast episode, voice memo or recording, \
            audiobook, sound effect or sample, music album
            """,
        confidence: nil,
        catches: "Music, voice memos, podcasts, samples, recordings."
    )

    static let archives = RuleTemplate(
        id: "archives",
        name: "Archives",
        prompt: """
            compressed archive or zip file, software installer or disk image, \
            backup bundle, downloaded software package
            """,
        confidence: nil,
        catches: "ZIP/tgz/DMG/PKG — anything that unpacks or installs."
    )

    static let code = RuleTemplate(
        id: "code",
        name: "Code",
        prompt: """
            source code file, script or program, software configuration file, \
            dataset or JSON data file, terminal log or error output, \
            developer tooling and build files, machine learning model weights, \
            project dependency list
            """,
        confidence: nil,
        catches: "Sources, scripts, configs, datasets, logs, dev tooling."
    )

    static let junk = RuleTemplate(
        id: "junk",
        name: "Junk",
        prompt: """
            temporary file, duplicate copy of a file, broken or partial download, \
            empty or untitled file, leftover cache file
            """,
        confidence: 0.85,
        catches: "Doubles, temp leftovers, throwaway clutter."
    )
}
