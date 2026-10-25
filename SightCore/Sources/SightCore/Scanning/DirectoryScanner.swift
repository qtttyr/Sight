import Foundation

/// Lists only the direct children of a root directory. Subdirectories are
/// intentionally never traversed.
public struct DirectoryScanner: Sendable {
    public init() {}

    public func scan(root: URL, includeHidden: Bool = false) throws -> [FileSnapshot] {
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey, .isRegularFileKey,
            .fileSizeKey, .contentModificationDateKey, .contentTypeKey,
        ]
        let options: FileManager.DirectoryEnumerationOptions = includeHidden ? [] : [.skipsHiddenFiles]
        let urls = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: options
        )

        // A single unreadable file — deleted between the listing and the
        // read, or blocked by the sandbox — must not lose the whole folder.
        var snapshots: [FileSnapshot] = []
        for url in urls {
            guard let snapshot = try? FileSnapshot(url: url) else { continue }
            guard !snapshot.isDirectory, !snapshot.isSymbolicLink, !snapshot.isTemporary else {
                continue
            }
            snapshots.append(snapshot)
        }
        return snapshots.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func isReady(_ file: FileSnapshot, grace: TimeInterval = 1.5) -> Bool {
        guard file.isRegularFile, !file.isTemporary else { return false }
        return Date.now.timeIntervalSince(file.modifiedAt) >= grace
    }
}
