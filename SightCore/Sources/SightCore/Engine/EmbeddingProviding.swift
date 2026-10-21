import Foundation

public enum EmbeddingKind: String, Sendable {
    case classification
    case searchQuery = "search_query"
    case document
}

public enum EmbeddingError: Error, LocalizedError, Sendable {
    case modelUnavailable
    case unsupportedModality(String)
    case invalidVector(dimension: Int, expected: Int)
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            "The on-device model is not available yet."
        case .unsupportedModality(let value):
            "This file type is not supported yet: \(value)."
        case .invalidVector(let dimension, let expected):
            "The model returned \(dimension) values; expected \(expected)."
        case .underlying(let message):
            message
        }
    }
}

/// The only surface through which Sight talks to an embedding model.
/// Keeping this narrow makes the rest of the app testable with a mock and
/// allows a future GGUF/Core ML implementation without touching the engine.
public protocol EmbeddingProviding: Sendable {
    var dimension: Int { get }
    func prepare() async throws
    func embed(text: String, kind: EmbeddingKind) async throws -> [Float]
    func embed(imageAt url: URL) async throws -> [Float]
}

public extension EmbeddingProviding {
    func embed(imageAt url: URL) async throws -> [Float] {
        throw EmbeddingError.unsupportedModality(url.pathExtension)
    }
}
