import AppKit
import PeekCore

/// Finds the display you're working on (the rule lives in ScreenPicker) from what macOS shares
/// with any app: the frontmost app's window positions, the mouse pointer and the screen list.
/// Window bounds don't need the Screen Recording permission; only window titles would.
enum ActiveScreen {
    static func current() -> NSScreen? {
        let screens = NSScreen.screens
        guard let main = screens.first else { return nil }
        let index = ScreenPicker.pick(screens: screens.map(\.frame),
                                      frontWindow: frontWindowFrame(mainScreenHeight: main.frame.height),
                                      pointer: NSEvent.mouseLocation)
        return screens.indices.contains(index) ? screens[index] : main
    }

    /// The frontmost app's frontmost ordinary window (normal layer, not a tiny helper), if any.
    private static func frontWindowFrame(mainScreenHeight: CGFloat) -> CGRect? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                    kCGNullWindowID) as? [[String: Any]] else { return nil }
        for window in list {   // ordered front to back
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (window[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let dict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary),
                  bounds.width >= 80, bounds.height >= 80 else { continue }
            return ScreenPicker.cocoaRect(fromWindowBounds: bounds, mainScreenHeight: mainScreenHeight)
        }
        return nil
    }
}

extension NSScreen {
    /// Survives the screen list being rebuilt (displays plugged in or rearranged), unlike the
    /// NSScreen object itself.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
