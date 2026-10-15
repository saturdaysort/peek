import Foundation
import PeekCore

/// Watches the inbox folder and hands each batch of new events to `onEvents` on the main queue.
/// The hook's rename into the folder is a directory write, which is what wakes us.
///
/// A watch follows the folder's inode, not its path. If the folder is deleted or moved away
/// (rm -rf, or the Peek folder dragged to the Trash) the hook recreates it at the old path and
/// a stale watch would never fire again. So the inbox and its parent are also watched for
/// delete and rename, and either one re-arms the whole watch on a fresh folder.
final class InboxWatcher {
    private let inbox: Inbox
    private let onEvents: ([PeekEvent]) -> Void
    private var sources: [DispatchSourceFileSystemObject] = []

    init(inbox: Inbox, onEvents: @escaping ([PeekEvent]) -> Void) {
        self.inbox = inbox
        self.onEvents = onEvents
    }

    func start() {
        try? FileManager.default.createDirectory(at: inbox.directory, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        drain()   // events that arrived while Peek wasn't running (stale ones are dropped)
        watch(inbox.directory, for: [.write, .delete, .rename])
        watch(inbox.directory.deletingLastPathComponent(), for: [.delete, .rename])
    }

    private func watch(_ folder: URL, for mask: DispatchSource.FileSystemEvent) {
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else {
            Log.info("cannot watch \(folder.path)")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: mask, queue: .main)
        source.setEventHandler { [weak self, unowned source] in
            if source.data.isDisjoint(with: [.delete, .rename]) {
                self?.drain()
            } else {
                self?.rearm(because: folder)
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        sources.append(source)
    }

    private func rearm(because folder: URL) {
        Log.info("\(folder.path) was moved or deleted; watching the inbox again")
        sources.forEach { $0.cancel() }
        sources.removeAll()
        start()
    }

    private func drain() {
        let events = inbox.drain()
        guard !events.isEmpty else { return }
        Log.info("received \(events.count) event(s)")
        onEvents(events)
    }
}
