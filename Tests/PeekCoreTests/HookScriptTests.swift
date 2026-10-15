import Foundation
import Testing
@testable import PeekCore

/// Runs hook/peek-hook the way Claude Code does: JSON on stdin, environment from the session.
private func runHook(stdin: Data, hostSessionId: String?, inbox: URL) throws -> Int32 {
    signal(SIGPIPE, SIG_IGN)   // the hook may exit before reading stdin; that must not kill the test
    let process = Process()
    process.executableURL = TestSupport.repoRoot.appendingPathComponent("hook/peek-hook")
    var env = ["HOME": NSHomeDirectory(), "PATH": "/usr/bin:/bin", "PEEK_INBOX": inbox.path]
    if let hostSessionId { env["CLAUDE_CODE_HOST_SESSION_ID"] = hostSessionId }
    process.environment = env
    let input = Pipe()
    process.standardInput = input
    try process.run()
    try? input.fileHandleForWriting.write(contentsOf: stdin)
    try? input.fileHandleForWriting.close()
    process.waitUntilExit()
    return process.terminationStatus
}

@Suite struct HookScriptTests {
    let inbox = TestSupport.tempDirectory().appendingPathComponent("inbox")
    let id = "local_12345678-1234-4abc-8def-123456789abc"
    let stop = Data(#"{"hook_event_name":"Stop","cwd":"/Users/me/Sites/demo-app","last_assistant_message":"All done."}"#.utf8)

    @Test func writesOneEnvelopePerEvent() throws {
        #expect(try runHook(stdin: stop, hostSessionId: id, inbox: inbox) == 0)
        #expect(try runHook(stdin: stop, hostSessionId: id, inbox: inbox) == 0)
        let names = try FileManager.default.contentsOfDirectory(atPath: inbox.path)
        #expect(names.filter { $0.hasSuffix(".event") }.count == 2)
        #expect(names.allSatisfy { !$0.hasPrefix(".") })   // no temp files left behind
        let events = Inbox(directory: inbox).drain()
        #expect(events.map(\.text) == ["All done.", "All done."])
        #expect(events.allSatisfy { $0.hostSessionId == id && $0.cwd == "/Users/me/Sites/demo-app" })
    }

    @Test func outsideClaudeDesktopItDoesNothing() throws {
        #expect(try runHook(stdin: stop, hostSessionId: nil, inbox: inbox) == 0)
        #expect(!FileManager.default.fileExists(atPath: inbox.path))
    }

    @Test func inboxIsPrivate() throws {
        _ = try runHook(stdin: stop, hostSessionId: id, inbox: inbox)
        let mode = try FileManager.default.attributesOfItem(atPath: inbox.path)[.posixPermissions] as? Int
        #expect(mode == 0o700)
    }

    @Test func hugePayloadIsCappedAndStillAnnounced() throws {
        let big = String(repeating: "x", count: 2_000_000)
        let json = Data(#"{"session_id":"x","cwd":"/Users/me/Sites/demo-app","hook_event_name":"Stop","last_assistant_message":"\#(big)"}"#.utf8)
        let started = Date()
        #expect(try runHook(stdin: json, hostSessionId: id, inbox: inbox) == 0)
        #expect(Date().timeIntervalSince(started) < 2)
        let file = try #require(try FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: [.fileSizeKey]).first)
        let size = try #require(try file.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        #expect(size <= 1_048_576 + id.utf8.count + 1)
        let events = Inbox(directory: inbox).drain()
        #expect(events.first?.kind == .done)
        #expect(events.first?.text == "Done")
    }
}
