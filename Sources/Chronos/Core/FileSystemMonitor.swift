import Foundation
import CoreServices

/// Uses FSEvents to watch directories and log all file-system changes
/// to the HistoryDatabase. Runs on a dedicated background queue.
actor FileSystemMonitor {
    static let shared = FileSystemMonitor()

    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "chronos.fsevents", qos: .utility)
    private var watchedPaths: [String] = []
    private var isRunning = false

    private init() {}

    // MARK: - Lifecycle

    func start(watching paths: [String]) {
        guard !paths.isEmpty else { return }
        stop()
        self.watchedPaths = paths
        self.isRunning = true

        queue.async { [weak self] in
            guard let self else { return }
            self.stream = self.createStream(paths: paths)
            guard let stream = self.stream else { return }
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
            CFRunLoopRun()
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    func addPath(_ path: String) {
        guard !watchedPaths.contains(path) else { return }
        watchedPaths.append(path)
        start(watching: watchedPaths)
    }

    func removePath(_ path: String) {
        watchedPaths.removeAll { $0 == path }
        start(watching: watchedPaths)
    }

    // MARK: - FSEvent Stream

    private func createStream(paths: [String]) -> FSEventStreamRef? {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let cfPaths = paths as CFArray

        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            guard let info = clientCallBackInfo else { return }
            let monitor = Unmanaged<FileSystemMonitor>.fromOpaque(info).takeUnretainedValue()
            let pathsArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

            Task { [pathsArray] in
                await monitor.handleEvents(paths: pathsArray, flags: eventFlags, count: numEvents)
            }
        }

        let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // latency: 500ms
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagUseCFTypes |
                kFSEventStreamCreateFlagFileEvents |
                kFSEventStreamCreateFlagNoDefer
            )
        )

        return stream
    }

    // MARK: - Event Handling

    private func handleEvents(paths: [String], flags: UnsafePointer<FSEventStreamEventFlags>, count: Int) {
        let fm = FileManager.default

        for i in 0..<count {
            let path = paths[i]
            let flag = flags[i]

            // Skip hidden files and system paths
            guard !shouldIgnore(path: path) else { continue }

            let eventType = eventType(from: flag)
            let parentPath = (path as NSString).deletingLastPathComponent
            let name = (path as NSString).lastPathComponent

            var isDir: ObjCBool = false
            let exists = fm.fileExists(atPath: path, isDirectory: &isDir)
            let size: Int64
            let inode: UInt64
            if exists {
                let attrs = try? fm.attributesOfItem(atPath: path)
                size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                inode = UInt64((attrs?[.systemFileNumber] as? NSNumber)?.int64Value ?? 0)
            } else {
                size = 0
                inode = 0
            }

            Task {
                try? await HistoryDatabase.shared.insertEvent(
                    path: path,
                    name: name,
                    parentPath: parentPath,
                    eventType: eventType,
                    timestamp: Date(),
                    size: size,
                    isDirectory: isDir.boolValue,
                    inode: inode
                )
            }
        }
    }

    private func eventType(from flag: FSEventStreamEventFlags) -> EventType {
        if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 { return .removed }
        if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0 { return .renamed }
        if flag & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 { return .created }
        return .modified
    }

    private func shouldIgnore(path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        if name.hasPrefix(".") { return true }
        let ignored = ["/private", "/dev", "/tmp", "/var", "/System", "/Library/Caches"]
        return ignored.contains { path.hasPrefix($0) }
    }
}
