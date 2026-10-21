import CoreServices
import Foundation

/// A small, root-only FSEvents stream. It emits changed paths and nothing else;
/// callers decide whether a path is a ready, sortable file.
public final class FSEventsMonitor: @unchecked Sendable {
    public typealias Handler = @Sendable ([URL]) -> Void

    private let queue = DispatchQueue(label: "app.sight.fsevents", qos: .utility)
    private var stream: FSEventStreamRef?
    private var handler: Handler?
    private var root: URL?

    public init() {}

    public func start(root: URL, handler: @escaping Handler) {
        stop()
        self.root = root.standardizedFileURL
        self.handler = handler

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
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
            guard let root = monitor.root else { return }
            let urls = array
                .map { URL(fileURLWithPath: $0).standardizedFileURL }
                .filter { $0.deletingLastPathComponent().standardizedFileURL == root }
            if !urls.isEmpty {
                monitor.handler?(urls)
            }
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [root.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.45,
            flags
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    public func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        self.handler = nil
        self.root = nil
    }

    deinit {
        stop()
    }
}
