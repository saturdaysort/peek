import Testing
@testable import PeekCore

@Suite struct DeepLinkTests {
    @Test func validIdBuildsTheContinueURL() {
        #expect(DeepLink.url(for: "local_12345678-1234-4abc-8def-123456789abc")?.absoluteString
            == "claude://code/continue?session=local_12345678-1234-4abc-8def-123456789abc")
    }

    @Test func sixtyFourCharactersIsTheLimit() {
        #expect(DeepLink.isValidSessionId("local_" + String(repeating: "a", count: 64)))
        #expect(!DeepLink.isValidSessionId("local_" + String(repeating: "a", count: 65)))
    }

    @Test(arguments: ["", "local_", "12345678", "session_abc", "local_abc def", "local_abc&x=1",
                      "local_abc\n", "local_ab/c", "local_é", "LOCAL_abc"])
    func everythingElseIsRejected(_ id: String) {
        #expect(DeepLink.url(for: id) == nil)
    }
}
