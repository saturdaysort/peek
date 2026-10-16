import AppKit
import PeekCore

/// AppKit colors for Sprite.Palette, the single source of the hex values.
enum Palette {
    static let clay = NSColor(hex: Sprite.Palette.clay)
    static let ink = NSColor(hex: Sprite.Palette.ink)
    static let paper = NSColor(hex: Sprite.Palette.paper)
    static let clayDark = NSColor(hex: Sprite.Palette.clayDark)
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
