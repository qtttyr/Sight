import Foundation

public struct ModelInstallProgress: Sendable {
    public let currentFile: String
    public let completedBytes: Int64
    public let currentFileBytes: Int64
    public let totalBytes: Int64
    public let fileFraction: Double

    public var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        let inFlight = Int64(Double(currentFileBytes) * fileFraction)
        return min(1, Double(completedBytes + inFlight) / Double(totalBytes))
    }
}

struct ModelInstallRecord: Codable, Sendable {
    let revision: String
    let assets: [ModelAsset]
    let installedAt: Date
}

public actor ModelStore {
    private nonisolated let root: URL
    private let downloader = ModelDownloader()
    private let recordName = ".sight-model.json"

    public init(root: URL = AppPaths.modelDirectory) {
        self.root = root
    }

    public nonisolated var modelDirectory: URL { root }

    public func isInstalled(_ assets: Set<ModelAsset>) -> Bool {
        guard let record = try? readRecord(), record.revision == ModelManifest.revision else {
            return false
        }
        let recorded = Set(record.assets)
        guard assets.isSubset(of: recorded) else { return false }
        return ModelManifest.files(for: assets).allSatisfy { file in
            let url = root.appendingPathComponent(file.path)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1
            return Int64(size) == file.size
        }
    }

    public func download(
        assets: Set<ModelAsset>,
        progress: @escaping @Sendable (ModelInstallProgress) -> Void
    ) async throws {
        try AppPaths.ensureDirectories()
        let files = ModelManifest.files(for: assets)
        let totalBytes = files.reduce(Int64(0)) { $0 + $1.size }
        var completedBytes: Int64 = 0

        for file in files {
            let destination = root.appendingPathComponent(file.path)
            let existingSize = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1
            if Int64(existingSize) == file.size {
                completedBytes += file.size
                progress(
                    ModelInstallProgress(
                        currentFile: file.path,
                        completedBytes: completedBytes,
                        currentFileBytes: file.size,
                        totalBytes: totalBytes,
                        fileFraction: 1
                    ))
                continue
            }

            let completedBeforeFile = completedBytes
            try await downloader.download(file, to: destination) { update in
                progress(
                    ModelInstallProgress(
                        currentFile: file.path,
                        completedBytes: completedBeforeFile,
                        currentFileBytes: file.size,
                        totalBytes: totalBytes,
                        fileFraction: update.fraction
                    ))
            }

            guard try downloader.verify(file: destination, expected: file.sha256) else {
                throw ModelDownloadError.checksumMismatch(file.path)
            }
            completedBytes += file.size
            progress(
                ModelInstallProgress(
                    currentFile: file.path,
                    completedBytes: completedBytes,
                    currentFileBytes: file.size,
                    totalBytes: totalBytes,
                    fileFraction: 1
                ))
        }

        try writeRecord(
            ModelInstallRecord(
                revision: ModelManifest.revision,
                assets: Array(assets),
                installedAt: .now
            ))
    }

    public func importModel(from source: URL) throws {
        try AppPaths.ensureDirectories()
        let fileManager = FileManager.default
        let sourceModel =
            source.lastPathComponent == "model"
            ? source
            : source.appendingPathComponent("model", isDirectory: true)
        guard fileManager.fileExists(atPath: sourceModel.path) else {
            throw ModelDownloadError.missingFile("model")
        }
        let destinationModel = root.appendingPathComponent("model", isDirectory: true)
        if fileManager.fileExists(atPath: destinationModel.path) {
            try fileManager.removeItem(at: destinationModel)
        }
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.copyItem(at: sourceModel, to: destinationModel)

        var assets: Set<ModelAsset> = [.text]
        if fileManager.fileExists(
            atPath: destinationModel.appendingPathComponent("embeddinggemma-2-vision.aimodel").path)
        {
            assets.insert(.vision)
        }
        if fileManager.fileExists(
            atPath: destinationModel.appendingPathComponent("embeddinggemma-2-audio.aimodel").path)
        {
            assets.insert(.audio)
        }
        try writeRecord(
            ModelInstallRecord(
                revision: ModelManifest.revision,
                assets: Array(assets),
                installedAt: .now
            ))
    }

    public func remove() throws {
        guard FileManager.default.fileExists(atPath: root.path) else { return }
        try FileManager.default.removeItem(at: root)
    }

    public func diskUsage() -> Int64 {
        guard
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.fileSizeKey]
            )
        else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
        return total
    }

    private func readRecord() throws -> ModelInstallRecord {
        let url = root.appendingPathComponent(recordName)
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ModelInstallRecord.self, from: data)
    }

    private func writeRecord(_ record: ModelInstallRecord) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(record)
        try data.write(to: root.appendingPathComponent(recordName), options: .atomic)
    }
}
