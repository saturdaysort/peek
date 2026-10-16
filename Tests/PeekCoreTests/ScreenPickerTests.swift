import CoreGraphics
import Testing
@testable import PeekCore

// Screen frames as macOS reports them (origin at the main screen's bottom-left): the dev Mac's
// built-in display with a Studio Display to its right.
private let builtIn = CGRect(x: 0, y: 0, width: 1800, height: 1169)
private let studio = CGRect(x: 1800, y: 0, width: 2880, height: 1620)
private let screens = [builtIn, studio]

@Suite struct ScreenPickerTests {
    @Test func picksTheScreenWithTheFrontWindow() {
        let window = CGRect(x: 2200, y: 300, width: 1200, height: 900)
        #expect(ScreenPicker.pick(screens: screens, frontWindow: window, pointer: CGPoint(x: 100, y: 100)) == 1)
    }

    @Test func aWindowAcrossTwoScreensBelongsToTheOneHoldingMostOfIt() {
        let mostlyRight = CGRect(x: 1500, y: 200, width: 1000, height: 600)   // 300 wide left, 700 right
        #expect(ScreenPicker.pick(screens: screens, frontWindow: mostlyRight, pointer: .zero) == 1)
        let mostlyLeft = CGRect(x: 1000, y: 200, width: 1000, height: 600)    // 800 wide left, 200 right
        #expect(ScreenPicker.pick(screens: screens, frontWindow: mostlyLeft, pointer: CGPoint(x: 3000, y: 500)) == 0)
    }

    @Test func withNoFrontWindowItFollowsThePointer() {
        #expect(ScreenPicker.pick(screens: screens, frontWindow: nil, pointer: CGPoint(x: 2500, y: 800)) == 1)
    }

    @Test func aWindowOffEveryScreenFallsBackToThePointer() {
        let offscreen = CGRect(x: -5000, y: -5000, width: 100, height: 100)
        #expect(ScreenPicker.pick(screens: screens, frontWindow: offscreen, pointer: CGPoint(x: 2500, y: 800)) == 1)
    }

    @Test func nothingToGoOnMeansTheMainScreen() {
        #expect(ScreenPicker.pick(screens: screens, frontWindow: nil, pointer: CGPoint(x: -10, y: -10)) == 0)
        #expect(ScreenPicker.pick(screens: [], frontWindow: nil, pointer: .zero) == 0)
    }

    @Test func windowBoundsFlipIntoScreenCoordinates() {
        // The window list measures from the main screen's top-left, with y growing downward.
        let bounds = CGRect(x: 2200, y: 100, width: 1200, height: 900)
        #expect(ScreenPicker.cocoaRect(fromWindowBounds: bounds, mainScreenHeight: 1169)
            == CGRect(x: 2200, y: 169, width: 1200, height: 900))
    }

    @Test func followsOnlyAnIdlePeekOnTheWrongScreen() {
        #expect(ScreenPicker.shouldFollow(phase: .peeking, animating: false, petScreen: 0, activeScreen: 1))
        #expect(!ScreenPicker.shouldFollow(phase: .peeking, animating: false, petScreen: 1, activeScreen: 1))
        #expect(!ScreenPicker.shouldFollow(phase: .peeking, animating: true, petScreen: 0, activeScreen: 1))
        #expect(!ScreenPicker.shouldFollow(phase: .showing, animating: false, petScreen: 0, activeScreen: 1))
        #expect(!ScreenPicker.shouldFollow(phase: .hidden, animating: false, petScreen: 0, activeScreen: 1))
    }
}
