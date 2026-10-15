import Testing
@testable import PeekCore

@Suite struct TextTrimmerTests {
    @Test func firstNonEmptyLine() {
        #expect(TextTrimmer.summary("\n\n  Fixed the header.\nMore detail here.") == "Fixed the header.")
    }

    @Test func stripsMarkdown() {
        #expect(TextTrimmer.summary("## **Done**: updated `Header.tsx` per [the spec](https://example.com/spec)")
            == "Done: updated Header.tsx per the spec")
    }

    @Test func stripsListAndQuoteMarkers() {
        #expect(TextTrimmer.summary("- first item") == "first item")
        #expect(TextTrimmer.summary("1. step one") == "step one")
        #expect(TextTrimmer.summary("> quoted") == "quoted")
    }

    @Test func skipsCodeFencesTablesAndRules() {
        let raw = "```swift\nlet x = 1\n```\n---\n| a | b |\nThe build passes."
        #expect(TextTrimmer.summary(raw) == "The build passes.")
    }

    @Test func collapsesWhitespace() {
        #expect(TextTrimmer.summary("a\t  b   c") == "a b c")
    }

    @Test func nothingUsableIsNil() {
        #expect(TextTrimmer.summary("") == nil)
        #expect(TextTrimmer.summary("  \n```\ncode only\n```\n") == nil)
    }

    @Test func keepsUnicode() {
        #expect(TextTrimmer.summary("Café déployé, 完了") == "Café déployé, 完了")
    }

    @Test func capsRunawayLines() {
        let summary = TextTrimmer.summary(String(repeating: "x", count: 100_000))
        #expect(summary?.count == TextTrimmer.maxLength)
    }

    @Test func keepsSnakeCase() {
        #expect(TextTrimmer.summary("renamed my_var") == "renamed my_var")
    }
}
