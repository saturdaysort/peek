import Foundation

/// What Peek reads from a Claude Desktop session file.
public struct SessionInfo: Sendable, Equatable {
    public let title: String?
    public let isArchived: Bool
    /// Milliseconds since 1970; updated when you switch to the session in Claude.
    public let lastFocusedAt: Double?

    public init(title: String?, isArchived: Bool, lastFocusedAt: Double?) {
        self.title = title
        self.isArchived = isArchived
        self.lastFocusedAt = lastFocusedAt
    }
}

/// Claude Desktop keeps one JSON file per Code session at
/// `<root>/<account-uuid>/<org-uuid>/local_<uuid>.json`. The layout is undocumented (observed in
/// Claude 2.37337.1), so every read here degrades to nil instead of failing.
public struct SessionDirectory: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public static var claudeDefault: SessionDirectory {
        SessionDirectory(root: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/claude-code-sessions"))
    }

    public func info(for id: String) -> SessionInfo? {
        guard DeepLink.isValidSessionId(id) else { return nil }
        for dir in orgDirectories() {
            if let info = Self.read(dir.appendingPathComponent("\(id).json")) { return info }
        }
        return nil
    }

    /// The session you most recently switched to. Only the `candidates` most recently modified
    /// files are read: there are hundreds of them (24 MB on the dev Mac), and switching to a
    /// session rewrites its file, so the answer is always among the newest.
    public func mostRecentlyFocusedId(candidates: Int = 5) -> String? {
        let fm = FileManager.default
        var files: [(url: URL, modified: Date)] = []
        for dir in orgDirectories() {
            let urls = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
            for url in urls where url.pathExtension == "json"
                && DeepLink.isValidSessionId(url.deletingPathExtension().lastPathComponent) {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                files.append((url, modified))
            }
        }
        var best: (id: String, at: Double)?
        for file in files.sorted(by: { $0.modified > $1.modified }).prefix(candidates) {
            guard let at = Self.read(file.url)?.lastFocusedAt else { continue }
            if best.map({ at > $0.at }) ?? true {
                best = (file.url.deletingPathExtension().lastPathComponent, at)
            }
        }
        return best?.id
    }

    /// The session's title, else its project folder's name, else "Claude".
    public static func displayTitle(info: SessionInfo?, cwd: String?) -> String {
        if let title = info?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return title }
        if let cwd, !cwd.isEmpty {
            let name = URL(fileURLWithPath: cwd).lastPathComponent
            if !name.isEmpty, name != "/" { return name }
        }
        return "Claude"
    }

    private func orgDirectories() -> [URL] {
        let fm = FileManager.default
        let accounts = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return accounts.flatMap { (try? fm.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? [] }
    }

    private static func read(_ file: URL) -> SessionInfo? {
        guard let data = try? Data(contentsOf: file),
              let raw = try? JSONDecoder().decode(RawSession.self, from: data) else { return nil }
        return SessionInfo(title: raw.title, isArchived: raw.isArchived ?? false, lastFocusedAt: raw.lastFocusedAt)
    }

    private struct RawSession: Decodable {
        let title: String?
        let isArchived: Bool?
        let lastFocusedAt: Double?
    }
}
