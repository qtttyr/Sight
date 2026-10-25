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
        case .alreadyInDestination: "A file with that name is already there."
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

    /// The final URL a file will take in a destination directory.
    ///
    /// The name is chosen here — and only here — so the journal can record
    /// the intent *before* the file is moved. A crash between the two then
    /// leaves a journal entry that points at a file that never arrived,
    /// which is harmless, instead of a moved file with no record at all.
    public func destination(
        for file: FileSnapshot,
        in directory: URL,
        root: URL,
        newName: String? = nil
    ) throws -> URL {
        let fileManager = FileManager.default
        let rootURL = root.standardizedFileURL.resolvingSymlinksInPath()
        let destination = directory.standardizedFileURL.resolvingSymlinksInPath()
        guard destination != rootURL else {
            throw SortError.destinationIsRoot
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let finalName = Self.safeName(newName, fallback: file.name)
        return collisionResolver.availableURL(for: finalName, in: destination)
    }

    /// Moves a file to an exact URL.
    public func move(_ file: FileSnapshot, to target: URL, root: URL) throws -> URL {
        guard file.isRegularFile, !file.isDirectory, !file.isSymbolicLink else {
            throw SortError.notAFile
        }

        let fileManager = FileManager.default
        let rootURL = root.standardizedFileURL.resolvingSymlinksInPath()
        let source = file.url.standardizedFileURL.resolvingSymlinksInPath()

        guard source.deletingLastPathComponent() == rootURL else {
            throw SortError.outsideRoot
        }
        guard target.deletingLastPathComponent() != rootURL else {
            throw SortError.destinationIsRoot
        }
        guard source != target else {
            throw SortError.alreadyInDestination
        }
        guard !fileManager.fileExists(atPath: target.path) else {
            throw SortError.alreadyInDestination
        }

        try fileManager.createDirectory(
            at: target.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var coordinationError: NSError?
        var moveError: Error?
        NSFileCoordinator().coordinate(writingItemAt: source, options: .forMoving, error: &coordinationError) {
            coordinatedSource in
            do {
                try fileManager.moveItem(at: coordinatedSource, to: target)
            } catch {
                // Only a move across volumes is worth a copy. Any other
                // failure is reported as is, so a half-finished copy can
                // never survive next to the original.
                guard Self.isCrossVolume(source: coordinatedSource, target: target) else {
                    moveError = error
                    return
                }
                do {
                    try fileManager.copyItem(at: coordinatedSource, to: target)
                    // Only a known size can be verified. An unknown size is
                    // not evidence of a failed copy.
                    let sourceSize = try? coordinatedSource.resourceValues(forKeys: [.fileSizeKey]).fileSize
                    let targetSize = try? target.resourceValues(forKeys: [.fileSizeKey]).fileSize
                    if let sourceSize, let targetSize {
                        guard sourceSize == targetSize else {
                            try? fileManager.removeItem(at: target)
                            throw SortError.moveFailed("Size verification failed during cross-volume move.")
                        }
                    }
                    try fileManager.removeItem(at: coordinatedSource)
                } catch {
                    // The copy failed or is incomplete: take it away again so
                    // the file is never duplicated.
                    try? fileManager.removeItem(at: target)
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

    /// True when source and destination live on different volumes, which is
    /// the only case where `moveItem` has to be replaced by a copy.
    static func isCrossVolume(source: URL, target: URL) -> Bool {
        guard let sourceVolume = volumeID(of: source),
            let targetVolume = volumeID(of: target.deletingLastPathComponent())
        else { return false }
        return sourceVolume != targetVolume
    }

    /// The device a path lives on. Two paths on the same disk share it.
    private static func volumeID(of url: URL) -> String? {
        var isDirectory: ObjCBool = false
        let path = url.path
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return nil }
        let directory = isDirectory.boolValue ? path : url.deletingLastPathComponent().path
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: directory)
        else { return nil }
        if let number = attributes[.systemFileNumber] as? NSNumber { return number.stringValue }
        return nil
    }

    /// A proposed name is trusted only if it is a plain file name.
    static func safeName(_ proposed: String?, fallback: String) -> String {
        guard let proposed, !proposed.isEmpty, !proposed.contains("/"), !proposed.contains(":"),
            !proposed.hasPrefix(".")
        else { return fallback }
        return proposed
    }

    /// Puts a file back where it came from. The journal does the same thing
    /// for whole batches; this is the single-file version.
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
