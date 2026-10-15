import Foundation
import PeekCore

/// Watches the inbox folder and hands each batch of new events to `onEvents` on the main queue.
/// The hook's rename into the folder is a directory write, which is what wakes us.
final class InboxWatcher {
    private let inbox: Inbox
    private let onEvents: ([PeekEvent]) -> Void
    private var source: DispatchSourceFileSystemObject?

    init(inbox: Inbox, onEvents: @escaping ([PeekEvent]) -> Void) {
        self.inbox = inbox
        self.onEvents = onEvents
    }

    func start() {
        try? FileManager.default.createDirectory(at: inbox.directory, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        drain()   // events that arrived while Peek wasn't running (stale ones are dropped)
        let fd = open(inbox.directory.path, O_EVTONLY)
        guard fd >= 0 else {
            Log.info("cannot watch \(inbox.directory.path)")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in self?.drain() }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    private func drain() {
        let events = inbox.drain()
        guard !events.isEmpty else { return }
        Log.info("received \(events.count) event(s)")
        onEvents(events)
    }
}
