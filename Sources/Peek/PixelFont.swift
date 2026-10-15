import AppKit
import CoreText

/// Press Start 2P, bundled in Contents/Resources (SIL Open Font License, Resources/OFL.txt).
/// Drawn only at 8 pt: the face is built on an 8 px grid, so 8 pt lands on exactly
/// 2 device pixels per font pixel on Retina. Any other size blurs.
enum PixelFont {
    static let size: CGFloat = 8
    static let lineHeight: CGFloat = 12
    private static let postScriptName = "PressStart2P-Regular"

    static func register() {
        guard let url = Bundle.main.url(forResource: "PressStart2P-Regular", withExtension: "ttf") else {
            Log.info("font missing from the bundle, using the system monospaced font")
            return
        }
        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            Log.info("font registration failed: \(String(describing: error?.takeRetainedValue()))")
        }
    }

    static var font: NSFont {
        NSFont(name: postScriptName, size: size) ?? .monospacedSystemFont(ofSize: 10, weight: .regular)
    }
}
