import Foundation
import Testing
@testable import PeekCore

@Suite struct InboxTests {
    let dir = TestSupport.tempDirectory()
    let id = "local_12345678-1234-4abc-8def-123456789abc"

    func write(_ name: String, _ contents: String, age: TimeInterval = 0) throws {
        let url = dir.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-age)], ofItemAtPath: url.path)
    }

    func stop(_ text: String) -> String {
        "\(id)\n{\"hook_event_name\":\"Stop\",\"last_assistant_message\":\"\(text)\"}"
    }

    @Test func drainsInNameOrderAndDeletes() throws {
        try write("1792086557000-2.event", stop("second"))
        try write("1792086556000-1.event", stop("first"))
        #expect(Inbox(directory: dir).drain().map(\.text) == ["first", "second"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }

    @Test func staleFilesAreDeletedUnread() throws {
        try write("1792086557000-3.event", stop("old news"), age: Inbox.staleAfter + 1)
        #expect(Inbox(directory: dir).drain().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }

    @Test func malformedFilesAreDeleted() throws {
        try write("1792086557000-4.event", "garbage")
        #expect(Inbox(directory: dir).drain().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).isEmpty)
    }

    @Test func halfWrittenTempFilesAreLeftAlone() throws {
        try write(".1792086557000-5.tmp", stop("still writing"))
        #expect(Inbox(directory: dir).drain().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == [".1792086557000-5.tmp"])
    }

    @Test func missingFolderIsEmpty() {
        #expect(Inbox(directory: dir.appendingPathComponent("nope")).drain().isEmpty)
    }

    @Test func hookAndAppAgreeOnTheInboxPath() throws {
        let hook = try String(contentsOf: TestSupport.repoRoot.appendingPathComponent("hook/peek-hook"), encoding: .utf8)
        #expect(hook.contains("$HOME/\(Inbox.relativePath)"))
    }
}
