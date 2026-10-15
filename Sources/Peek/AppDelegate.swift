import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        PixelFont.register()
        Log.info("launched, font \(PixelFont.font.fontName)")
    }
}
