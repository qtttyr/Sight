import Foundation
import UniformTypeIdentifiers

/// An immutable snapshot of a file at the root of a watched directory.
///
/// Sight deliberately never descends into directories. A snapshot therefore
/// always describes a single entry in the root, never a tree.
public struct FileSnapshot: Identifiable, Hashable, Sendable {
    public let id: String
    public let url: URL
    public let name: String
    public let fileExtension: String
    public let size: Int64
    public let modifiedAt: Date
    public let contentType: UTType
    public let isDirectory: Bool
    public let isSymbolicLink: Bool
    public let isHidden: Bool
    public let isRegularFile: Bool

    /// A synthetic snapshot used by the zero-shot tester. It never touches the
    /// file system and is never passed to the executor.
    public init(name: String, url: URL, contentType: UTType = .text) {
        self.id = url.standardizedFileURL.path
        self.url = url.standardizedFileURL
        self.name = name
        self.fileExtension = url.pathExtension.lowercased()
        self.size = 0
        self.modifiedAt = .now
        self.contentType = contentType
        self.isDirectory = false
        self.isSymbolicLink = false
        self.isHidden = false
        self.isRegularFile = true
    }

    public init(url: URL) throws {
        let values = try url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isHiddenKey,
            .isRegularFileKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .contentTypeKey,
        ])

        self.id = url.standardizedFileURL.path
        self.url = url.standardizedFileURL
        self.name = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        self.size = Int64(values.fileSize ?? 0)
        self.modifiedAt = values.contentModificationDate ?? .distantPast
        self.contentType = values.contentType ?? .data
        self.isDirectory = values.isDirectory ?? false
        self.isSymbolicLink = values.isSymbolicLink ?? false
        self.isHidden = values.isHidden ?? false
        self.isRegularFile = values.isRegularFile ?? false
    }

    public var displayName: String {
        name.isEmpty ? url.lastPathComponent : name
    }

    public var isTemporary: Bool {
        let temporaryExtensions: Set<String> = [
            "download", "crdownload", "part", "partial", "tmp", "temp", "swp", "lock",
        ]
        if temporaryExtensions.contains(fileExtension) { return true }
        return name.hasPrefix(".") || name == ".DS_Store"
    }
}
