import AppKit
import PeekCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: PetController?
    private var watcher: InboxWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        PixelFont.register()
        let controller = PetController(quietUntil: Settings.quietUntil)
        controller.installMenu()
        controller.scheduleQuietEnd()
        self.controller = controller
        watcher = InboxWatcher(inbox: .standard) { controller.receive($0) }
        watcher?.start()
        LoginItem.apply()
        Log.info("launched, font \(PixelFont.font.fontName)")
    }

    /// Opening Peek while it's running (Finder, Spotlight, `open`) brings the pet out.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.greet()
        return false
    }
}
