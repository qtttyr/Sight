import Foundation

/// A user-defined destination and the natural-language description that
/// defines what belongs inside it.
public struct CategoryRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var prompt: String
    public var destination: URL
    public var isEnabled: Bool
    public var threshold: Float?

    public init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        destination: URL,
        isEnabled: Bool = true,
        threshold: Float? = nil
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.destination = destination
        self.isEnabled = isEnabled
        self.threshold = threshold
    }

    /// A stable description of the semantic content of a rule. Used to avoid
    /// re-embedding prompts that have not changed.
    public var semanticSignature: String {
        "\(name.lowercased())|\(prompt.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    public var isValid: Bool {
        isEnabled
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && destination.isFileURL
    }
}
