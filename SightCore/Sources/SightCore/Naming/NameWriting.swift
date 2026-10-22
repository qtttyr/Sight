import Foundation

/// A tiny language model that writes short names. It does the jobs an
/// embedding model cannot: reading a document and saying what it *is* in two
/// or three words, and naming a folder for a group of files.
///
/// Everything it returns is validated by `FileNamer.sanitize`, so a wild
/// answer can never become a file name.
public protocol NameWriting: Sendable {
    /// `true` when the model can run right now.
    var isAvailable: Bool { get }
    /// A 2–4 word title for a file, in the language of its content.
    func fileTitle(currentName: String, kind: String, excerpt: String) async -> String?
    /// A 1–2 word folder name for files with these titles.
    func folderName(samples: [String]) async -> String?
}

#if canImport(FoundationModels)
import FoundationModels

@Generable
private struct GeneratedTitle {
    @Guide(description: "A short topical title of two to four words. No dates, numbers, ids, quotes, or file extension.")
    var title: String
}

@Generable
private struct GeneratedFolder {
    @Guide(description: "A general folder name of one or two words that covers every item.")
    var name: String
}

/// Apple's on-device language model (Foundation Models). It ships with macOS,
/// needs no download, never leaves the Mac, and understands many languages.
public struct AppleNameWriter: NameWriting {
    public init() {}

    public var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    public func fileTitle(currentName: String, kind: String, excerpt: String) async -> String? {
        guard isAvailable else { return nil }
        let session = LanguageModelSession(instructions: """
            You name files. Reply with a short, general, topical title of two to four words that \
            says what the file is about. Write it in the same language as the content. \
            Never include dates, numbers, ids, quotes, the word "file", or an extension. \
            Prefer the general subject ("Hackathon Rules") over specific details.
            """)
        let prompt = """
            Current name: \(currentName)
            Type: \(kind)
            Content:
            \(excerpt)
            """
        let options = GenerationOptions(temperature: 0.2, maximumResponseTokens: 24)
        guard let response = try? await session.respond(to: prompt, generating: GeneratedTitle.self, options: options)
        else { return nil }
        return response.content.title
    }

    public func folderName(samples: [String]) async -> String? {
        guard isAvailable, !samples.isEmpty else { return nil }
        let session = LanguageModelSession(instructions: """
            You name folders. Given titles of files that belong together, reply with one general \
            folder name of one or two words, in the same language as the titles. \
            Use a broad subject ("Recipes"), never a single file's detail.
            """)
        let prompt = "Files:\n" + samples.prefix(12).map { "- \($0)" }.joined(separator: "\n")
        let options = GenerationOptions(temperature: 0.1, maximumResponseTokens: 12)
        guard let response = try? await session.respond(to: prompt, generating: GeneratedFolder.self, options: options)
        else { return nil }
        return response.content.name
    }
}
#endif
