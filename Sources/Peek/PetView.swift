import AppKit
import PeekCore

/// Draws the pet, its bubble and the badge from a `State` snapshot, and reports clicks, scrolls
/// and right-clicks on them. It has no behavior of its own; PetController decides everything.
final class PetView: NSView {
    struct State: Equatable {
        var pose = Pose.offstage
        var stride = false
        var blinking = false
        var bubble: Message?
        var revealed = 0
        var popScale = 0.0
        var bangOn = true
        var badge = 0
        /// "1 of 3" and the Next button, when more than one message waits.
        var pager: Director.Pager?
        var nextHovered = false
    }

    var state = State() {
        didSet { if state != oldValue { needsDisplay = true } }
    }
    var onClick: (() -> Void)?
    var onNext: (() -> Void)?
    var onScroll: ((Int) -> Void)?
    var menuProvider: (() -> NSMenu?)?

    private var scrollAccumulator: CGFloat = 0
    private var cachedLayout: BubbleLayout?

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Geometry

    /// Feet on the bottom edge, 12 pt in from the right edge.
    private var homeRect: NSRect {
        NSRect(x: bounds.maxX - Geometry.rightInset - Sprite.width, y: 0, width: Sprite.width, height: Sprite.height)
    }

    private var petRect: NSRect { homeRect.offsetBy(dx: state.pose.x, dy: state.pose.y) }

    private var layout: BubbleLayout? {
        guard let message = state.bubble else { return nil }
        if cachedLayout?.message != message || cachedLayout?.pager != state.pager {
            cachedLayout = BubbleLayout(message: message, pager: state.pager, petHome: homeRect)
        }
        return cachedLayout
    }

    private var badgeText: NSAttributedString? {
        guard state.badge > 0 else { return nil }
        return NSAttributedString(string: "\(state.badge)", attributes: [.font: PixelFont.font, .foregroundColor: Palette.paper])
    }

    /// On the pet's top-right corner, so it stays visible while peeking.
    private var badgeRect: NSRect? {
        guard let text = badgeText else { return nil }
        let width = ceil(text.size().width) + 6
        return NSRect(x: petRect.maxX - width + 3, y: petRect.maxY - 3, width: width, height: PixelFont.lineHeight)
    }

    private var mousePoint: NSPoint? {
        guard let window else { return nil }
        return convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
    }

    /// True when the pointer is on the bubble's Next button (only once the bubble has fully popped).
    var isMouseOverNext: Bool {
        guard let point = mousePoint, state.popScale >= 1, let next = layout?.nextRect else { return false }
        return next.contains(point)
    }

    /// True when the pointer is over something visible: the pet, the badge, or a fully popped bubble.
    var containsMouse: Bool {
        guard let point = mousePoint else { return false }
        var targets = [petRect.intersection(bounds)]
        if let badge = badgeRect { targets.append(badge) }
        if let layout, state.popScale >= 1 { targets.append(layout.frame) }
        return targets.contains { !$0.isEmpty && $0.contains(point) }
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        // Next flips to the next message; anywhere else on the bubble or pet opens this one.
        if isMouseOverNext {
            onNext?()
        } else if containsMouse {
            onClick?()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        // Trackpads send many small precise deltas; mouse wheels send whole lines.
        scrollAccumulator += event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 20
        while abs(scrollAccumulator) >= 20 {
            onScroll?(scrollAccumulator > 0 ? -1 : 1)
            scrollAccumulator -= scrollAccumulator > 0 ? 20 : -20
        }
    }

    /// True while the right-click menu is open. The bubble's countdown treats it like hovering,
    /// so the pet doesn't duck while you're choosing what to do with its message.
    private(set) var isMenuOpen = false
    private var menuObserver: NSObjectProtocol?

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let menu = menuProvider?() else { return nil }
        isMenuOpen = true
        if let menuObserver { NotificationCenter.default.removeObserver(menuObserver) }
        menuObserver = NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification,
                                                              object: menu, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.isMenuOpen = false
            if let observer = self.menuObserver { NotificationCenter.default.removeObserver(observer) }
            self.menuObserver = nil
        }
        return menu
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        paint(Sprite.rows(stride: state.stride, blinking: state.blinking), at: petRect.origin, cell: Sprite.pixel, in: ctx)
        if let layout, let message = state.bubble, state.popScale > 0 {
            ctx.saveGState()
            // Pop out of the tail corner.
            ctx.translateBy(x: layout.frame.maxX, y: layout.frame.minY)
            ctx.scaleBy(x: state.popScale, y: state.popScale)
            ctx.translateBy(x: -layout.frame.maxX, y: -layout.frame.minY)
            drawBubble(layout, message: message, in: ctx)
            ctx.restoreGState()
        }
        drawBadge(in: ctx)
    }

    /// Paints a pixel map (rows top to bottom) with its bottom-left cell at `origin`.
    private func paint(_ rows: [String], at origin: NSPoint, cell: CGFloat, in ctx: CGContext) {
        for (r, row) in rows.enumerated() {
            let y = origin.y + CGFloat(rows.count - 1 - r) * cell
            for (c, ch) in row.enumerated() {
                guard let hex = Sprite.color(ch) else { continue }
                ctx.setFillColor(NSColor(hex: hex).cgColor)
                ctx.fill(CGRect(x: origin.x + CGFloat(c) * cell, y: y, width: cell, height: cell))
            }
        }
    }

    private func drawBubble(_ layout: BubbleLayout, message: Message, in ctx: CGContext) {
        let frame = layout.frame
        let b = BubbleLayout.border
        // Ink with notched corners: two overlapping bars leave each b x b corner clear.
        ctx.setFillColor(Palette.ink.cgColor)
        ctx.fill(frame.insetBy(dx: b, dy: 0))
        ctx.fill(frame.insetBy(dx: 0, dy: b))
        ctx.setFillColor(Palette.paper.cgColor)
        ctx.fill(frame.insetBy(dx: b, dy: b))
        paint(Sprite.tail, at: layout.tailOrigin, cell: Sprite.tailPixel, in: ctx)
        let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        layout.titleString(bangOn: state.bangOn).draw(with: layout.titleRect, options: options)
        layout.bodyString(revealed: state.revealed).draw(with: layout.bodyRect, options: options)
        if let pager = layout.pager, let counterRect = layout.counterRect, let nextRect = layout.nextRect {
            BubbleLayout.counterString(pager).draw(with: counterRect, options: options)
            ctx.setFillColor((state.nextHovered ? Palette.clayDark : Palette.ink).cgColor)
            ctx.fill(nextRect)
            let label = nextRect.insetBy(dx: BubbleLayout.chipPadding, dy: 0)
            let line = NSRect(x: label.minX, y: label.minY + ((label.height - PixelFont.lineHeight) / 2).rounded(),
                              width: label.width, height: PixelFont.lineHeight)
            BubbleLayout.nextString().draw(with: line, options: options)
        }
    }

    private func drawBadge(in ctx: CGContext) {
        guard let text = badgeText, let rect = badgeRect else { return }
        ctx.setFillColor(Palette.ink.cgColor)
        ctx.fill(rect)
        text.draw(at: NSPoint(x: rect.minX + 3, y: rect.minY + 2))
    }
}
