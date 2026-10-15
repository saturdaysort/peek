import Foundation
import Testing
@testable import PeekCore

@Suite struct SessionDirectoryTests {
    let root = TestSupport.tempDirectory()

    /// Mirrors Claude Desktop's layout: <root>/<account>/<org>/<id>.json, plus unrelated keys.
    func addSession(_ id: String, title: String? = nil, archived: Bool = false, focused: Double? = nil,
                    account: String = "acct-1", org: String = "org-1") throws {
        let dir = root.appendingPathComponent(account).appendingPathComponent(org)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var object: [String: Any] = ["sessionId": id, "isArchived": archived, "cwd": "/Users/me/Sites/demo-app",
                                     "toolSurfaceSnapshot": ["tools": ["Bash", "Read"]]]
        if let title { object["title"] = title }
        if let focused { object["lastFocusedAt"] = focused }
        try JSONSerialization.data(withJSONObject: object).write(to: dir.appendingPathComponent("\(id).json"))
    }

    @Test func readsTheTitleUnderAnyAccount() throws {
        try addSession("local_aaa", title: "Fix the header", account: "acct-2", org: "org-9")
        #expect(SessionDirectory(root: root).info(for: "local_aaa")
            == SessionInfo(title: "Fix the header", isArchived: false, lastFocusedAt: nil))
    }

    @Test func readsArchivedAndFocus() throws {
        try addSession("local_bbb", archived: true, focused: 1_792_086_557_845)
        let info = SessionDirectory(root: root).info(for: "local_bbb")
        #expect(info?.isArchived == true)
        #expect(info?.lastFocusedAt == 1_792_086_557_845)
    }

    @Test func unknownOrInvalidIdsAreNil() throws {
        try addSession("local_ccc", title: "x")
        let sessions = SessionDirectory(root: root)
        #expect(sessions.info(for: "local_zzz") == nil)
        #expect(sessions.info(for: "../../etc/passwd") == nil)
        #expect(SessionDirectory(root: root.appendingPathComponent("missing")).info(for: "local_ccc") == nil)
    }

    @Test func displayTitleFallsBackToTheFolderThenClaude() {
        let titled = SessionInfo(title: "Fix the header", isArchived: false, lastFocusedAt: nil)
        let blank = SessionInfo(title: "  ", isArchived: false, lastFocusedAt: nil)
        #expect(SessionDirectory.displayTitle(info: titled, cwd: "/a/b") == "Fix the header")
        #expect(SessionDirectory.displayTitle(info: blank, cwd: "/Users/me/Sites/demo-app") == "demo-app")
        #expect(SessionDirectory.displayTitle(info: nil, cwd: "/") == "Claude")
        #expect(SessionDirectory.displayTitle(info: nil, cwd: nil) == "Claude")
    }

    @Test func mostRecentlyFocusedPicksTheNewestFocus() throws {
        try addSession("local_one", focused: 100)
        try addSession("local_two", focused: 300)
        try addSession("local_three", focused: 200)
        try addSession("local_four")
        #expect(SessionDirectory(root: root).mostRecentlyFocusedId() == "local_two")
    }

    @Test func mostRecentlyFocusedReadsOnlyRecentlyModifiedFiles() throws {
        try addSession("local_old", focused: 999)
        let old = root.appendingPathComponent("acct-1/org-1/local_old.json")
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -86_400)], ofItemAtPath: old.path)
        try addSession("local_new", focused: 1)
        #expect(SessionDirectory(root: root).mostRecentlyFocusedId(candidates: 1) == "local_new")
    }

    @Test func mostRecentlyFocusedWithNoSessionsIsNil() {
        #expect(SessionDirectory(root: root).mostRecentlyFocusedId() == nil)
    }
}
