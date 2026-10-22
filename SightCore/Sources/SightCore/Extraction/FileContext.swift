import Foundation

public struct FileContext: Sendable {
    public enum Payload: Sendable {
        case text(String)
        case image(URL)
        case none
    }

    public let file: FileSnapshot
    public let payload: Payload
    /// A text signal that is available even when the payload is an image:
    /// the cleaned file name and its kind. `nil` when the name carries no
    /// information (`IMG_0059.PNG`), so it cannot drag the decision around.
    public let hint: String?
    /// Deterministic evidence from type, name conventions and image metadata.
    public let profile: TypeProfile
    /// The readable content alone (no name, no type description).
    public let body: String
    /// A real document title (PDF metadata), if the file has one.
    public let title: String?
    public let imageFacts: ImageFacts?

    public init(
        file: FileSnapshot,
        payload: Payload,
        hint: String? = nil,
        profile: TypeProfile = .empty,
        body: String = "",
        title: String? = nil,
        imageFacts: ImageFacts? = nil
    ) {
        self.body = body
        self.title = title
        self.imageFacts = imageFacts
        self.file = file
        self.payload = payload
        self.hint = hint
        self.profile = profile
    }

    public var text: String? {
        if case .text(let value) = payload { return value }
        return nil
    }

    public var imageURL: URL? {
        if case .image(let url) = payload { return url }
        return nil
    }
}
