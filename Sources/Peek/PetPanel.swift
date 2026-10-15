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

    func anchor() {
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        setFrameOrigin(NSPoint(x: visible.maxX - Self.size.width, y: visible.minY))
    }
}
