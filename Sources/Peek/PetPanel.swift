import AppKit

/// A transparent, borderless, non-activating panel pinned to the bottom-right corner of the
/// menu-bar display's visible frame (above the Dock). It is flush with both edges; the view
/// insets the pet and clips whatever walks or ducks past them.
final class PetPanel: NSPanel {
    static let size = NSSize(width: 380, height: 170)

    convenience init() {
        self.init(contentRect: NSRect(origin: .zero, size: Self.size),
                  styleMask: [.borderless, .nonactivatingPanel],
                  backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// The display the pet is on, by display ID.
    private(set) var screenID: CGDirectDisplayID?

    /// Bottom-right of that screen's visible frame, above its Dock.
    func anchor(to screen: NSScreen) {
        screenID = screen.displayID
        let visible = screen.visibleFrame
        setFrameOrigin(NSPoint(x: visible.maxX - Self.size.width, y: visible.minY))
    }

    /// After displays change: stay on the same screen if it's still connected, else the active one.
    func reanchor() {
        let same = NSScreen.screens.first { $0.displayID != nil && $0.displayID == screenID }
        if let screen = same ?? ActiveScreen.current() { anchor(to: screen) }
    }
}
