import Foundation

public struct FileContext: Sendable {
    public enum Payload: Sendable {
        case text(String)
        case image(URL)
        case none
    }

    public let file: FileSnapshot
    public let payload: Payload

    public init(file: FileSnapshot, payload: Payload) {
        self.file = file
        self.payload = payload
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
