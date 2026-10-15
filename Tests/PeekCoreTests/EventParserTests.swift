import Foundation
import Testing
@testable import PeekCore

private let id = "local_12345678-1234-4abc-8def-123456789abc"
private let now = Date(timeIntervalSince1970: 1_792_086_557)
private func envelope(_ json: String, id: String = id) -> Data { Data((id + "\n" + json).utf8) }

@Suite struct EventParserTests {
    @Test func stopBecomesDone() {
        let json = #"{"session_id":"9f8e7d6c-5b4a-4321-8fed-cba987654321","transcript_path":"/Users/me/.claude/projects/demo/9f8e7d6c.jsonl","cwd":"/Users/me/Sites/demo-app","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"**Fixed** the header.\n\nDetails follow."}"#
        #expect(EventParser.parse(envelope(json), receivedAt: now)
            == PeekEvent(hostSessionId: id, kind: .done, text: "Fixed the header.", cwd: "/Users/me/Sites/demo-app", receivedAt: now))
    }

    @Test(arguments: ["permission_prompt", "elicitation_dialog"])
    func attentionNotificationsBecomeNeedsYou(_ type: String) {
        let json = #"{"session_id":"x","transcript_path":"/t","cwd":"/Users/me/Sites/demo-app","hook_event_name":"Notification","message":"Claude needs your permission to use Bash","notification_type":"\#(type)"}"#
        let event = EventParser.parse(envelope(json), receivedAt: now)
        #expect(event?.kind == .needsYou)
        #expect(event?.text == "Claude needs your permission to use Bash")
    }

    @Test(arguments: ["idle_prompt", "auth_success"])
    func repeatAndNoiseNotificationsAreDropped(_ type: String) {
        let json = #"{"hook_event_name":"Notification","message":"Claude is waiting for your input","notification_type":"\#(type)"}"#
        #expect(EventParser.parse(envelope(json), receivedAt: now) == nil)
    }

    @Test func emptyTextFallsBack() {
        #expect(EventParser.parse(envelope(#"{"hook_event_name":"Stop","last_assistant_message":""}"#), receivedAt: now)?.text == "Done")
        #expect(EventParser.parse(envelope(#"{"hook_event_name":"Stop"}"#), receivedAt: now)?.text == "Done")
        #expect(EventParser.parse(envelope(#"{"hook_event_name":"Notification"}"#), receivedAt: now)?.text == "Needs you")
    }

    @Test func otherEventsAreIgnored() {
        #expect(EventParser.parse(envelope(#"{"hook_event_name":"SubagentStop"}"#), receivedAt: now) == nil)
    }

    @Test func malformedEnvelopesAreIgnored() {
        #expect(EventParser.parse(Data("no newline at all".utf8), receivedAt: now) == nil)
        #expect(EventParser.parse(envelope("{not json"), receivedAt: now) == nil)
        #expect(EventParser.parse(envelope("[]"), receivedAt: now) == nil)
        #expect(EventParser.parse(envelope(#"{"hook_event_name":"Stop"}"#, id: "local_bad id"), receivedAt: now) == nil)
    }

    @Test func truncatedPayloadStillAnnounces() {
        let cut = #"{"session_id":"x","cwd":"/Users/me/Sites/demo-app","hook_event_name":"Stop","last_assistant_message":"aaaaaaaa"#
        let event = EventParser.parse(envelope(cut), receivedAt: now)
        #expect(event?.kind == .done)
        #expect(event?.text == "Done")
        #expect(event?.cwd == "/Users/me/Sites/demo-app")
    }
}
