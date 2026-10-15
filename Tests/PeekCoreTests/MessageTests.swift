import Foundation
import Testing
@testable import PeekCore

@Suite struct MessageTests {
    @Test func fallbackTextMatchesTheSpec() {
        #expect(MessageKind.done.fallbackText == "Done")
        #expect(MessageKind.needsYou.fallbackText == "Needs you")
    }

    @Test func messageFromEventKeepsEverythingAndAddsTheTitle() {
        let at = Date(timeIntervalSince1970: 1_792_086_557)
        let event = PeekEvent(hostSessionId: "local_a", kind: .needsYou, text: "Allow Bash?", cwd: "/x", receivedAt: at)
        #expect(Message(event: event, title: "Fix the header")
            == Message(hostSessionId: "local_a", kind: .needsYou, title: "Fix the header", text: "Allow Bash?", receivedAt: at))
    }
}
