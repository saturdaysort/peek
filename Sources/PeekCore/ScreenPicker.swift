import CoreGraphics

/// Which display the pet uses: the one you're working on. That is the screen holding your
/// frontmost window (also the one whose menu bar is active), else the screen under the mouse
/// pointer, else the main screen. Frames are in macOS screen coordinates: origin at the main
/// screen's bottom-left, y growing upward.
public enum ScreenPicker {
    /// Index into `screens` of the screen to use.
    public static func pick(screens: [CGRect], frontWindow: CGRect?, pointer: CGPoint) -> Int {
        if let window = frontWindow {
            let overlaps = screens.map { area($0.intersection(window)) }
            if let best = overlaps.indices.max(by: { overlaps[$0] < overlaps[$1] }), overlaps[best] > 0 {
                return best
            }
        }
        return screens.firstIndex { $0.contains(pointer) } ?? 0
    }

    /// The window list (CGWindowListCopyWindowInfo) measures from the main screen's top-left with
    /// y growing downward; this flips a window's bounds into screen coordinates.
    public static func cocoaRect(fromWindowBounds bounds: CGRect, mainScreenHeight: CGFloat) -> CGRect {
        CGRect(x: bounds.minX, y: mainScreenHeight - bounds.maxY, width: bounds.width, height: bounds.height)
    }

    /// A peek follows you to another screen only when it is just sitting there: never while the
    /// bubble is out (you may be reading it) and never mid-animation.
    public static func shouldFollow<ID: Equatable>(phase: Director.Phase, animating: Bool,
                                                    petScreen: ID, activeScreen: ID) -> Bool {
        phase == .peeking && !animating && petScreen != activeScreen
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}
