import Foundation

/// Where the pet is, relative to its home spot in the corner.
public struct Pose: Sendable, Equatable {
    /// Points toward the right screen edge. 0 is home; `Geometry.offstage` is fully past the edge.
    public var x: Double
    /// Points upward. Negative values sink the pet below the bottom edge (ducking).
    public var y: Double
    /// True while the legs should alternate.
    public var walking: Bool

    public init(x: Double, y: Double, walking: Bool = false) {
        self.x = x
        self.y = y
        self.walking = walking
    }

    public static let home = Pose(x: 0, y: 0)
    public static let offstage = Pose(x: Geometry.offstage, y: 0)
}

/// Every duration, in seconds, in one place.
public enum Timing {
    public static let walkInDone = 1.1
    public static let walkInNeedsYou = 0.7
    public static let walkOut = 0.9
    /// One hop is two halves: up, then down.
    public static let hopHalf = 0.11
    public static let duck = 0.42
    public static let unduck = 0.16
    public static let legFrame = 0.13
    public static let blinkEvery = 2.6
    public static let blinkFor = 0.14
    public static let bubblePop = 0.18
    public static let typeOn = 1.5
    public static let bubbleStays = 10.0
    public static let bangBlink = 0.5

    /// How often the app's clock ticks: smoothly while anything moves, slowly while the pet just
    /// peeks. A peek can last hours, and a 60 Hz timer on an idle agent shows up as battery drain.
    public static func tickInterval(phase: Director.Phase, animating: Bool) -> Double {
        animating || phase != .peeking ? 1.0 / 60 : 0.1
    }
}

/// Distances, in points.
public enum Geometry {
    public static let rightInset = 12.0
    /// Far enough right that the pet is entirely past the screen edge.
    public static let offstage = rightInset + Sprite.width + 8
    public static let hopHeight = 10.0
    /// While peeking, the top three sprite rows (the eyes) stay above the edge.
    public static let peekShowing = 3 * Sprite.pixel
    public static let duckDepth = Sprite.height - peekShowing
}

/// One animation as a pure function of elapsed time. Walking moves in whole sprite pixels and
/// vertical moves are stepped, so the motion reads as pixel art rather than smooth easing.
public struct Motion: Sendable {
    public let animation: Director.Animation
    public let from: Pose

    public init(_ animation: Director.Animation, from: Pose) {
        self.animation = animation
        self.from = from
    }

    public var duration: Double {
        switch animation {
        case .duck: Timing.duck
        case .unduck: Timing.unduck
        default: walkDuration + Double(hops) * 2 * Timing.hopHalf
        }
    }

    public func isFinished(at elapsed: Double) -> Bool { elapsed >= duration }

    public func pose(at elapsed: Double) -> Pose {
        let t = min(max(elapsed, 0), duration)
        switch animation {
        case .duck:
            return Pose(x: from.x, y: stepped(from: from.y, to: -Geometry.duckDepth, progress: t / Timing.duck, steps: 6))
        case .unduck:
            return Pose(x: from.x, y: stepped(from: from.y, to: 0, progress: t / Timing.unduck, steps: 3))
        default:
            break
        }
        if let target = walkTarget, t < walkDuration {
            let x = from.x + (target - from.x) * (t / walkDuration)
            return Pose(x: snapped(x), y: groundY, walking: true)
        }
        let hopTime = t - walkDuration
        let inHops = hopTime < Double(hops) * 2 * Timing.hopHalf
        let up = inHops && Int(hopTime / Timing.hopHalf) % 2 == 0
        return Pose(x: walkTarget ?? from.x, y: groundY + (up ? Geometry.hopHeight : 0))
    }

    private var walkTarget: Double? {
        switch animation {
        // A hop walks home first: a click during the walk-in can start one from mid-walk.
        case .enter, .enterPeeking, .hop: 0
        case .leave: Geometry.offstage
        case .duck, .unduck: nil
        }
    }

    /// Walks cover distance at a fixed speed, so turning back halfway doesn't sprint.
    private var walkDuration: Double {
        guard let target = walkTarget else { return 0 }
        let fullWalk: Double
        switch animation {
        case .enter(.needsYou): fullWalk = Timing.walkInNeedsYou
        case .leave: fullWalk = Timing.walkOut
        default: fullWalk = Timing.walkInDone
        }
        return fullWalk * abs(target - from.x) / Geometry.offstage
    }

    private var hops: Int {
        switch animation {
        case .enter(.done), .hop: 1
        case .enter(.needsYou): 2
        case .enterPeeking, .duck, .unduck, .leave: 0
        }
    }

    /// The height the pet walks and lands at.
    private var groundY: Double {
        switch animation {
        case .enterPeeking: -Geometry.duckDepth
        case .leave: from.y
        default: 0
        }
    }

    private func snapped(_ x: Double) -> Double { (x / Sprite.pixel).rounded() * Sprite.pixel }

    private func stepped(from a: Double, to b: Double, progress: Double, steps: Int) -> Double {
        let q = (min(max(progress, 0), 1) * Double(steps)).rounded(.up) / Double(steps)
        return a + (b - a) * q
    }
}
