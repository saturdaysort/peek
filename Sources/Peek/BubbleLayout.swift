import AppKit
import PeekCore

/// Size and placement of the speech bubble for one message, measured once per message (and per
/// counter value, when several are waiting).
struct BubbleLayout {
    static let maxWidth: CGFloat = 248
    static let minWidth: CGFloat = 120
    static let border: CGFloat = 3
    static let padding: CGFloat = 8
    static let titleGap: CGFloat = 4
    static let bodyLines = 3
    /// The bubble overlaps the pet's left edge by this much, so the tail lands on its head.
    static let overlap: CGFloat = 14
    /// Space between the pet's head and the bubble's bottom edge, where the tail hangs.
    static let lift: CGFloat = 17
    /// The "1 of 3 ... Next >" row under the message.
    static let footerGap: CGFloat = 6
    static let footerHeight: CGFloat = 16
    static let chipPadding: CGFloat = 4
    static let counterGap: CGFloat = 12

    let message: Message
    let pager: Director.Pager?
    let frame: NSRect
    let titleRect: NSRect
    let bodyRect: NSRect
    let tailOrigin: NSPoint
    /// The counter's text line, and the clickable Next button. Nil without a pager.
    let counterRect: NSRect?
    let nextRect: NSRect?

    init(message: Message, pager: Director.Pager?, petHome: NSRect) {
        self.message = message
        self.pager = pager
        let chrome = 2 * (Self.border + Self.padding)
        let maxText = Self.maxWidth - chrome
        let titleWidth = Self.title(for: message, bangOn: true).size().width
        let body = Self.text(message.text, color: Palette.ink, lineBreak: .byWordWrapping)
        let counterWidth = pager.map { ceil(Self.counterString($0).size().width) } ?? 0
        let chipWidth = pager == nil ? 0 : ceil(Self.nextString().size().width) + 2 * Self.chipPadding
        let footerWidth = pager == nil ? 0 : counterWidth + Self.counterGap + chipWidth
        let textWidth = min(maxText, ceil(max(titleWidth, body.size().width, footerWidth)))
        let bodyHeight = body.boundingRect(with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                                           options: .usesLineFragmentOrigin).height
        let lines = max(1, min(Self.bodyLines, Int((bodyHeight / PixelFont.lineHeight).rounded(.up))))
        let footer = pager == nil ? 0 : Self.footerGap + Self.footerHeight

        let width = max(Self.minWidth, textWidth + chrome).rounded(.up)
        let height = (CGFloat(1 + lines) * PixelFont.lineHeight + Self.titleGap + footer + chrome).rounded(.up)
        frame = NSRect(x: (petHome.minX + Self.overlap - width).rounded(), y: petHome.maxY + Self.lift,
                       width: width, height: height)

        let inner = frame.insetBy(dx: Self.border + Self.padding, dy: Self.border + Self.padding)
        titleRect = NSRect(x: inner.minX, y: inner.maxY - PixelFont.lineHeight,
                           width: inner.width, height: PixelFont.lineHeight)
        bodyRect = NSRect(x: inner.minX, y: inner.minY + footer,
                          width: inner.width, height: CGFloat(lines) * PixelFont.lineHeight)
        if pager != nil {
            let lineY = inner.minY + ((Self.footerHeight - PixelFont.lineHeight) / 2).rounded()
            counterRect = NSRect(x: inner.minX, y: lineY, width: counterWidth, height: PixelFont.lineHeight)
            nextRect = NSRect(x: inner.maxX - chipWidth, y: inner.minY, width: chipWidth, height: Self.footerHeight)
        } else {
            counterRect = nil
            nextRect = nil
        }
        // The tail's top row sits on the bottom border, near the right edge, pointing at the pet.
        tailOrigin = NSPoint(x: frame.maxX - 30,
                             y: frame.minY - CGFloat(Sprite.tail.count - 1) * Sprite.tailPixel)
    }

    func titleString(bangOn: Bool) -> NSAttributedString {
        Self.title(for: message, bangOn: bangOn)
    }

    /// The whole message laid out, with the first `revealed` characters inked and the rest
    /// clear, so typing on never reflows the lines.
    func bodyString(revealed: Int) -> NSAttributedString {
        let text = message.text
        let s = NSMutableAttributedString(attributedString: Self.text(text, color: .clear, lineBreak: .byWordWrapping))
        let end = text.index(text.startIndex, offsetBy: min(max(revealed, 0), text.count))
        s.addAttribute(.foregroundColor, value: Palette.ink, range: NSRange(text.startIndex..<end, in: text))
        return s
    }

    static func counterString(_ pager: Director.Pager) -> NSAttributedString {
        text(pager.label, color: Palette.ink.withAlphaComponent(0.6), lineBreak: .byClipping)
    }

    static func nextString() -> NSAttributedString {
        text(Director.Pager.nextTitle, color: Palette.paper, lineBreak: .byClipping)
    }

    private static func title(for message: Message, bangOn: Bool) -> NSAttributedString {
        let s = NSMutableAttributedString()
        if message.kind == .needsYou {
            s.append(text("! ", color: bangOn ? Palette.ink : .clear, lineBreak: .byTruncatingTail))
        }
        s.append(text(message.title, color: Palette.ink.withAlphaComponent(0.6), lineBreak: .byTruncatingTail))
        return s
    }

    private static func text(_ string: String, color: NSColor, lineBreak: NSLineBreakMode) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = PixelFont.lineHeight
        paragraph.maximumLineHeight = PixelFont.lineHeight
        paragraph.lineBreakMode = lineBreak
        return NSAttributedString(string: string, attributes: [
            .font: PixelFont.font, .foregroundColor: color, .paragraphStyle: paragraph,
        ])
    }
}
