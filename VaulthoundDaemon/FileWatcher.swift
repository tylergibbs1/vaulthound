import Foundation
import CoreServices

/// Watches directories for `.env` file changes using FSEvents.
final class FileWatcher {
    typealias ChangeHandler = (VaulthoundModels.FileChangeEvent) -> Void

    private var streams: [String: FSEventStreamRef] = [:]
    private var handlers: [String: ChangeHandler] = [:]

    func watch(directory: String, handler: @escaping ChangeHandler) {
        guard streams[directory] == nil else { return }

        handlers[directory] = handler

        var context = FSEventStreamContext()
        context.info = Unmanaged.passRetained(WatcherContext(directory: directory, watcher: self)).toOpaque()

        let pathsToWatch = [directory] as CFArray

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,  // latency in seconds
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        streams[directory] = stream
    }

    func unwatch(directory: String) {
        guard let stream = streams.removeValue(forKey: directory) else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        handlers.removeValue(forKey: directory)
    }

    func unwatchAll() {
        for dir in Array(streams.keys) {
            unwatch(directory: dir)
        }
    }

    fileprivate func handleEvent(directory: String, path: String, flags: FSEventStreamEventFlags) {
        guard path.contains(".env") else { return }

        let changeType: VaulthoundModels.FileChangeEvent.ChangeType
        if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 {
            changeType = .created
        } else if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 {
            changeType = .deleted
        } else {
            changeType = .modified
        }

        let event = VaulthoundModels.FileChangeEvent(
            path: path,
            projectPath: directory,
            changeType: changeType
        )

        handlers[directory]?(event)
    }

    deinit {
        unwatchAll()
    }
}

private class WatcherContext {
    let directory: String
    weak var watcher: FileWatcher?

    init(directory: String, watcher: FileWatcher) {
        self.directory = directory
        self.watcher = watcher
    }
}

import VaulthoundModels

private func fsEventsCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let context = Unmanaged<WatcherContext>.fromOpaque(info).takeUnretainedValue()

    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as? [String] ?? []

    for i in 0..<numEvents {
        guard i < paths.count else { break }
        context.watcher?.handleEvent(directory: context.directory, path: paths[i], flags: eventFlags[i])
    }
}
