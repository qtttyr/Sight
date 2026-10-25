import CoreServices
import Foundation

/// FSEvents keeps the context alive for as long as the stream runs, so the
/// monitor cannot be freed while a callback is still in flight.
private func retainMonitor(_ info: UnsafeRawPointer?) -> UnsafeRawPointer? {
    guard let info else { return nil }
    return UnsafeRawPointer(Unmanaged<FSEventsMonitor>.fromOpaque(info).retain().toOpaque())
}

private func releaseMonitor(_ info: UnsafeRawPointer?) {
    guard let info else { return }
    Unmanaged<FSEventsMonitor>.fromOpaque(info).release()
}

/// A small, root-only FSEvents stream. It emits changed paths and nothing else;
/// callers decide whether a path is a ready, sortable file.
public final class FSEventsMonitor: @unchecked Sendable {
    public typealias Handler = @Sendable ([URL]) -> Void

    private let queue = DispatchQueue(label: "app.sight.fsevents", qos: .utility)
    /// The stream callback runs on `queue` while `start`/`stop` run on the
    /// caller's thread. Everything they share is behind this lock.
    private let lock = NSLock()
    private var stream: FSEventStreamRef?
    private var handler: Handler?
    private var root: URL?

    public init() {}

    public func start(root: URL, handler: @escaping Handler) {
        stop()
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: retainMonitor,
            release: releaseMonitor,
            copyDescription: nil
        )

        let flags = UInt32(
            kFSEventStreamCreateFlagUseCFTypes
                | kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagNoDefer
                | kFSEventStreamCreateFlagWatchRoot
        )

        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info, count > 0 else { return }
            let monitor = Unmanaged<FSEventsMonitor>.fromOpaque(info).takeUnretainedValue()
            guard let array = unsafeBitCast(paths, to: NSArray.self) as? [String] else { return }
            let urls =
                array
                .map { URL(fileURLWithPath: $0).standardizedFileURL }
                .filter { url in monitor.isAtRoot(url) }
            if !urls.isEmpty {
                monitor.fire(urls)
            }
        }

        guard
            let stream = FSEventStreamCreate(
                kCFAllocatorDefault,
                callback,
                &context,
                [root.path] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.45,
                flags
            )
        else { return }

        lock.lock()
        self.root = root.standardizedFileURL
        self.handler = handler
        self.stream = stream
        lock.unlock()

        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    public func stop() {
        lock.lock()
        let stream = self.stream
        self.stream = nil
        self.handler = nil
        self.root = nil
        lock.unlock()

        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    deinit {
        stop()
    }

    // MARK: - Thread-safe access

    private func isAtRoot(_ url: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let root else { return false }
        return url.deletingLastPathComponent().standardizedFileURL == root
    }

    private func fire(_ urls: [URL]) {
        lock.lock()
        let handler = self.handler
        lock.unlock()
        handler?(urls)
    }
}
