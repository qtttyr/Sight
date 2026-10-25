import CryptoKit
import Foundation

public struct DownloadProgress: Sendable {
    public let fileName: String
    public let bytesWritten: Int64
    public let totalBytes: Int64

    public var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(bytesWritten) / Double(totalBytes))
    }
}

public enum ModelDownloadError: Error, LocalizedError, Sendable {
    case badStatus(Int)
    case checksumMismatch(String)
    case missingFile(String)
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .badStatus(let code): "The model server returned HTTP \(code)."
        case .checksumMismatch(let name): "The downloaded file failed verification: \(name)."
        case .missingFile(let name): "The model file is missing: \(name)."
        case .underlying(let message): message
        }
    }
}

public final class ModelDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private struct State {
        let file: ModelFile
        let destination: URL
        let progress: @Sendable (DownloadProgress) -> Void
        let continuation: CheckedContinuation<Void, Error>
        var error: Error?
    }

    private var session: URLSession?
    private var states: [Int: State] = [:]
    private let lock = NSLock()

    public override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    public func download(
        _ file: ModelFile,
        to destination: URL,
        progress: @escaping @Sendable (DownloadProgress) -> Void
    ) async throws {
        guard let url = URL(string: "\(ModelManifest.baseURL)/\(file.path)") else {
            throw ModelDownloadError.missingFile(file.path)
        }
        guard let session else { throw ModelDownloadError.missingFile(file.path) }
        let task = session.downloadTask(with: url)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            states[task.taskIdentifier] = State(
                file: file,
                destination: destination,
                progress: progress,
                continuation: continuation,
                error: nil
            )
            lock.unlock()
            task.resume()
        }
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        lock.lock()
        let state = states[downloadTask.taskIdentifier]
        lock.unlock()
        guard let state else { return }
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : state.file.size
        state.progress(
            DownloadProgress(
                fileName: state.file.path,
                bytesWritten: totalBytesWritten,
                totalBytes: total
            ))
    }

    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        lock.lock()
        let state = states[downloadTask.taskIdentifier]
        lock.unlock()
        guard var state else { return }

        if let response = downloadTask.response as? HTTPURLResponse, response.statusCode != 200 {
            state.error = ModelDownloadError.badStatus(response.statusCode)
        } else {
            do {
                let fileManager = FileManager.default
                try fileManager.createDirectory(
                    at: state.destination.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if fileManager.fileExists(atPath: state.destination.path) {
                    try fileManager.removeItem(at: state.destination)
                }
                try fileManager.moveItem(at: location, to: state.destination)
            } catch {
                state.error = ModelDownloadError.underlying(error.localizedDescription)
            }
        }

        lock.lock()
        states[downloadTask.taskIdentifier] = state
        lock.unlock()
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        let state = states.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        guard let state else { return }
        if let error {
            state.continuation.resume(throwing: error)
        } else if let stateError = state.error {
            state.continuation.resume(throwing: stateError)
        } else {
            state.continuation.resume()
        }
    }

    public func verify(file: URL, expected: String) throws -> Bool {
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw ModelDownloadError.missingFile(file.lastPathComponent)
        }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let data = try handle.read(upToCount: 4 * 1024 * 1024), !data.isEmpty {
            hasher.update(data: data)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return digest == expected
    }
}
