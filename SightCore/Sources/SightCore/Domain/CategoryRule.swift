import Foundation

/// A user-defined destination and the natural-language description that
/// defines what belongs inside it.
public struct CategoryRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var prompt: String
    public var destination: URL
    public var isEnabled: Bool
    /// Optional per-rule confidence: the relative distance this rule needs
    /// between itself and the runner-up before it may propose a category.
    /// `nil` means "use the global confidence".
    public var threshold: Float?
    /// Identifies rules that came from the curated library. Their prompt and
    /// confidence are refreshed when the library improves; rules the user
    /// wrote themselves (`nil`) are never touched.
    public var libraryID: String?

    public init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        destination: URL,
        isEnabled: Bool = true,
        threshold: Float? = nil,
        libraryID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.destination = destination
        self.isEnabled = isEnabled
        self.threshold = threshold
        self.libraryID = libraryID
    }

    /// A stable description of the semantic content of a rule. Used to avoid
    /// re-embedding prompts that have not changed.
    public var semanticSignature: String {
        "\(name.lowercased())|\(prompt.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// The deterministic file family this rule stands for, if any. Library
    /// rules carry it in `libraryID`; hand-written rules get it from an
    /// unambiguous name such as "Movies" or "Музыка".
    public var kind: FileKind? {
        if let libraryID, let kind = FileKind(rawValue: libraryID) { return kind }
        return FileKind.infer(fromRuleName: name)
    }

    /// The prompt, split into the separate ideas it lists. Each idea becomes
    /// its own embedding, so "invoice, receipt, tax return" is matched as three
    /// sharp concepts instead of one blurred average. A prompt without
    /// separators is a single anchor. The rule name always joins in.
    public var anchors: [String] {
        var seen = Set<String>()
        var result: [String] = []
        let separators = CharacterSet(charactersIn: ",;\n•")
        let pieces = prompt.components(separatedBy: separators) + [name]
        for piece in pieces {
            let cleaned =
                piece
                .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            guard cleaned.count >= 2 else { continue }
            if seen.insert(cleaned.lowercased()).inserted { result.append(cleaned) }
            if result.count >= 48 { break }
        }
        return result
    }

    public var isValid: Bool {
        isEnabled
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && destination.isFileURL
    }
}
