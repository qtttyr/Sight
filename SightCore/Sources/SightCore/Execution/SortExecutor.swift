import Foundation

public enum SortError: Error, LocalizedError, Sendable {
    case notAFile
    case outsideRoot
    case destinationIsRoot
    case alreadyInDestination
    case coordinationFailed(String)
    case moveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAFile: "Only regular files can be sorted."
        case .outsideRoot: "The file is outside the watched folder."
        case .destinationIsRoot: "A file cannot be moved into the watched root."
        case .alreadyInDestination: "The file is already in this destination."
        case .coordinationFailed(let message): "The file could not be coordinated: \(message)"
        case .moveFailed(let message): "The file could not be moved: \(message)"
        }
    }
}

/// The only type allowed to mutate the user's files. Every guard lives here so
/// the UI cannot accidentally bypass it.
public actor SortExecutor {
    private let collisionResolver = CollisionResolver()

    public init() {}

    public func move(
        _ file: FileSnapshot,
        to destinationDirectory: URL,
        root: URL,
        newName: String? = nil
    ) throws -> URL {
        guard file.isRegularFile, !file.isDirectory, !file.isSymbolicLink else {
            throw SortError.notAFile
        }

        let fileManager = FileManager.default
        let rootURL = root.standardizedFileURL.resolvingSymlinksInPath()
        let source = file.url.standardizedFileURL
        let destination = destinationDirectory.standardizedFileURL.resolvingSymlinksInPath()

        guard source.deletingLastPathComponent() == rootURL else {
            throw SortError.outsideRoot
        }
        guard destination != rootURL else {
            throw SortError.destinationIsRoot
        }
        guard source.deletingLastPathComponent() != destination else {
            throw SortError.alreadyInDestination
        }

        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let finalName = Self.safeName(newName, fallback: file.name)
        let target = collisionResolver.availableURL(for: finalName, in: destination)

        var coordinationError: NSError?
        var moveError: Error?
        NSFileCoordinator().coordinate(writingItemAt: source, options: .forMoving, error: &coordinationError) { coordinatedSource in
            do {
                try fileManager.moveItem(at: coordinatedSource, to: target)
            } catch {
                // Cross-volume moves can fail inside FileManager. Fall back to a
                // verified copy + remove rather than losing the file.
                do {
                    try fileManager.copyItem(at: coordinatedSource, to: target)
                    let sourceSize = (try? coordinatedSource.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1
                    let targetSize = (try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -2
                    guard sourceSize == targetSize else {
                        try? fileManager.removeItem(at: target)
                        throw SortError.moveFailed("Size verification failed during cross-volume move.")
                    }
                    try fileManager.removeItem(at: coordinatedSource)
                } catch {
                    moveError = error
                }
            }
        }

        if let coordinationError {
            throw SortError.coordinationFailed(coordinationError.localizedDescription)
        }
        if let moveError {
            throw SortError.moveFailed(moveError.localizedDescription)
        }
        return target
    }

    /// A proposed name is trusted only if it is a plain file name.
    static func safeName(_ proposed: String?, fallback: String) -> String {
        guard let proposed, !proposed.isEmpty, !proposed.contains("/"), !proposed.contains(":"),
              !proposed.hasPrefix(".")
        else { return fallback }
        return proposed
    }

    public func restore(_ entry: JournalEntry) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: entry.destination.path) else {
            throw SortError.moveFailed("The sorted file no longer exists.")
        }
        guard !fileManager.fileExists(atPath: entry.source.path) else {
            throw SortError.moveFailed("A file already exists at the original path.")
        }
        try fileManager.createDirectory(
            at: entry.source.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.moveItem(at: entry.destination, to: entry.source)
    }
}
