import Foundation

/// The Block buddy and the bubble tail as pixel maps. This file is the single source of truth
/// for the character's shape and colors; the app only scales and paints it.
/// Map characters: `o` clay, `k` ink, `p` paper, `.` clear.
public enum Sprite {
    /// Points per sprite pixel: 10 device pixels on Retina, so edges stay crisp.
    public static let pixel = 5.0
    public static let columns = 16

    public static let body: [String] = [
        "..oooooooooooo..",
        "..ookkooookkoo..",
        "..ookkooookkoo..",
        "oooooooooooooooo",
        "oooooooooooooooo",
        "..oooooooooooo..",
        "..oooooooooooo..",
    ]
    /// Standing pose, and one of the two walking frames.
    public static let legsA: [String] = [
        "..o.o......o.o..",
        "..o.o......o.o..",
    ]
    public static let legsB: [String] = [
        "...o.o....o.o...",
        "...o.o....o.o...",
    ]

    public static let rowCount = body.count + legsA.count
    public static let width = Double(columns) * pixel
    public static let height = Double(rowCount) * pixel

    /// Drawn at `tailPixel` points per cell. The top row overlaps the bubble's 3 pt bottom border,
    /// so its paper cells open the border into the tail.
    public static let tailPixel = 3.0
    public static let tail: [String] = [
        "kppppk",
        ".kpppk",
        "..kppk",
        "...kpk",
        "....kk",
    ]

    public enum Palette {
        public static let clay: UInt32 = 0xD97757
        public static let ink: UInt32 = 0x1F1A17
        public static let paper: UInt32 = 0xFFFDF8
        /// Hover color for the bubble's Next button; paper text on it stays readable.
        public static let clayDark: UInt32 = 0xA9502F
    }

    /// Rows from top to bottom. `stride` shows the mid-step legs; `blinking` closes the eyes.
    public static func rows(stride: Bool, blinking: Bool) -> [String] {
        let rows = body + (stride ? legsB : legsA)
        return blinking ? rows.map { $0.replacingOccurrences(of: "k", with: "o") } : rows
    }

    public static func color(_ c: Character) -> UInt32? {
        switch c {
        case "o": Palette.clay
        case "k": Palette.ink
        case "p": Palette.paper
        default: nil
        }
    }
}
