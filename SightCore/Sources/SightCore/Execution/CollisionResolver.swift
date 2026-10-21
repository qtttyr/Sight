import Foundation

public struct CollisionResolver: Sendable {
    public init() {}

    /// Returns a destination URL that does not exist. The original extension is
    /// preserved, and the suffix is deterministic: `name (1).ext`.
    public func availableURL(for fileName: String, in directory: URL, fileManager: FileManager = .default) -> URL {
        let original = directory.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: original.path) else { return original }

        let url = URL(fileURLWithPath: fileName)
        let base = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension
        var index = 1

        while index < 1_000 {
            let candidateName = pathExtension.isEmpty
                ? "\(base) (\(index))"
                : "\(base) (\(index)).\(pathExtension)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }

        return directory.appendingPathComponent("\(base) (\(UUID().uuidString)).\(pathExtension)")
    }
}
