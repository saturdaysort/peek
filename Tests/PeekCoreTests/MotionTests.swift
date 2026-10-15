import Testing
@testable import PeekCore

private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

@Suite struct MotionTests {
    @Test func doneEntranceWalksInThenHopsOnce() {
        let m = Motion(.enter(.done), from: .offstage)
        #expect(close(m.duration, 1.1 + 0.22))
        #expect(m.pose(at: 0) == Pose(x: Geometry.offstage, y: 0, walking: true))
        #expect(m.pose(at: 1.15) == Pose(x: 0, y: Geometry.hopHeight))
        #expect(m.pose(at: 1.26) == Pose(x: 0, y: 0))
        #expect(m.pose(at: m.duration) == .home)
        #expect(m.isFinished(at: m.duration))
        #expect(!m.isFinished(at: 1.0))
    }

    @Test func needsYouEntranceIsFasterWithTwoBounces() {
        let m = Motion(.enter(.needsYou), from: .offstage)
        #expect(close(m.duration, 0.7 + 0.44))
        #expect(m.pose(at: 0.75).y == Geometry.hopHeight)
        #expect(m.pose(at: 0.86).y == 0)
        #expect(m.pose(at: 0.97).y == Geometry.hopHeight)
        #expect(m.pose(at: m.duration) == .home)
    }

    @Test func walkingMovesInWholeSpritePixels() {
        let m = Motion(.enter(.done), from: .offstage)
        for step in 0...110 {
            #expect(m.pose(at: Double(step) / 100).x.truncatingRemainder(dividingBy: Sprite.pixel) == 0)
        }
    }

    @Test func duckLeavesOnlyTheEyesShowing() {
        let m = Motion(.duck, from: .home)
        #expect(Geometry.duckDepth == 30)
        #expect(m.pose(at: m.duration).y == -30)
        #expect(m.pose(at: 0.1).y.truncatingRemainder(dividingBy: Sprite.pixel) == 0)
    }

    @Test func unduckReturnsHome() {
        #expect(Motion(.unduck, from: Pose(x: 0, y: -30)).pose(at: Timing.unduck) == .home)
    }

    @Test func hopGoesUpThenDown() {
        let m = Motion(.hop, from: .home)
        #expect(close(m.duration, 0.22))
        #expect(m.pose(at: 0.05).y == Geometry.hopHeight)
        #expect(m.pose(at: 0.2).y == 0)
    }

    @Test func leavingFromThePeekStaysDucked() {
        let m = Motion(.leave, from: Pose(x: 0, y: -30))
        #expect(m.pose(at: 0.3).y == -30)
        #expect(m.pose(at: 0.3).walking)
        #expect(m.pose(at: m.duration) == Pose(x: Geometry.offstage, y: -30))
    }

    @Test func walksKeepAConstantSpeed() {
        #expect(close(Motion(.leave, from: .home).duration, 0.9))
        #expect(close(Motion(.leave, from: Pose(x: 50, y: 0)).duration, 0.45))
    }

    @Test func peekingEntranceWalksInDucked() {
        let m = Motion(.enterPeeking, from: .offstage)
        #expect(m.pose(at: 0.5).y == -30)
        #expect(m.pose(at: m.duration) == Pose(x: 0, y: -30))
    }
}
