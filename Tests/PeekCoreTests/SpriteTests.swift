import Testing
@testable import PeekCore

@Suite struct SpriteTests {
    @Test func everyRowIsSixteenWide() {
        for row in Sprite.body + Sprite.legsA + Sprite.legsB { #expect(row.count == Sprite.columns) }
    }

    @Test func spriteIsEightyByFortyFivePoints() {
        #expect(Sprite.rows(stride: false, blinking: false).count == 9)
        #expect(Sprite.width == 80)
        #expect(Sprite.height == 45)
    }

    @Test func onlyKnownPixels() {
        for row in Sprite.body + Sprite.legsA + Sprite.legsB { #expect(row.allSatisfy { ".ok".contains($0) }) }
        for row in Sprite.tail {
            #expect(row.count == 6)
            #expect(row.allSatisfy { ".kp".contains($0) })
        }
    }

    @Test func blinkingClosesBothEyes() {
        func ink(_ rows: [String]) -> Int { rows.joined().filter { $0 == "k" }.count }
        #expect(ink(Sprite.rows(stride: false, blinking: false)) == 8)
        #expect(ink(Sprite.rows(stride: false, blinking: true)) == 0)
    }

    @Test func theEyesFitInThePeek() {
        let peekRows = Int(Geometry.peekShowing / Sprite.pixel)
        let rows = Sprite.rows(stride: false, blinking: false)
        #expect(rows.prefix(peekRows).joined().filter { $0 == "k" }.count == 8)
    }

    @Test func strideMovesTheLegs() {
        #expect(Sprite.rows(stride: true, blinking: false) != Sprite.rows(stride: false, blinking: false))
    }

    @Test func paletteMatchesTheSpec() {
        #expect(Sprite.Palette.clay == 0xD97757)
        #expect(Sprite.Palette.ink == 0x1F1A17)
        #expect(Sprite.Palette.paper == 0xFFFDF8)
        #expect(Sprite.color("o") == 0xD97757)
        #expect(Sprite.color("k") == 0x1F1A17)
        #expect(Sprite.color("p") == 0xFFFDF8)
        #expect(Sprite.color(".") == nil)
    }
}
