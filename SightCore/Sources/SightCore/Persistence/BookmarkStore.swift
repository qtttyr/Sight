import Foundation

public enum BookmarkError: Error, LocalizedError, Sendable {
    case creationFailed(String)
    case resolutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .creationFailed(let message): "Could not remember this folder: \(message)"
        case .resolutionFailed(let message): "Could not reopen this folder: \(message)"
        }
    }
}

public enum BookmarkStore {
    public static func makeBookmark(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkError.creationFailed(error.localizedDescription)
        }
    }

    public static func resolve(_ data: Data) throws -> (url: URL, isStale: Bool) {
        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            return (url, stale)
        } catch {
            throw BookmarkError.resolutionFailed(error.localizedDescription)
        }
    }
}
