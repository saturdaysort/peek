import Foundation

/// The drop folder between the hook and the app. The hook writes `<epoch-ms>-<pid>.event`
/// files atomically (temp file, then rename); the app drains them in name order.
public struct Inbox: Sendable {
    /// Relative to the home folder. hook/peek-hook hard-codes the same path; a test keeps them in step.
    public static let relativePath = "Library/Application Support/Peek/inbox"
    /// Older events are dropped unread, so a long absence doesn't produce a flood.
    public static let staleAfter: TimeInterval = 3600
    /// The hook's 1 MB cap plus the id line, with room to spare. Bigger files didn't come from the hook.
    public static let maxFileSize = 2 * 1024 * 1024

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static var standard: Inbox {
        Inbox(directory: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(relativePath))
    }

    /// Parses and deletes every `.event` file, oldest name first. Stale, oversized and malformed
    /// files are deleted without producing an event. Dot-prefixed temp files are left alone.
    public func drain(now: Date = Date()) -> [PeekEvent] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys) else { return [] }
        var events: [PeekEvent] = []
        let ready = files.filter { $0.pathExtension == "event" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for file in ready {
            defer { try? fm.removeItem(at: file) }
            let values = try? file.resourceValues(forKeys: Set(keys))
            let modified = values?.contentModificationDate ?? now
            guard now.timeIntervalSince(modified) < Self.staleAfter,
                  (values?.fileSize ?? 0) <= Self.maxFileSize,
                  let data = try? Data(contentsOf: file),
                  let event = EventParser.parse(data, receivedAt: modified) else { continue }
            events.append(event)
        }
        return events
    }
}
