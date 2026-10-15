import Foundation

/// Turns Claude's final Markdown message into one line of plain text for a speech bubble.
public enum TextTrimmer {
    /// The bubble shows about 90 characters. Capping well above that keeps a runaway one-line
    /// message (a minified blob near the hook's 1 MB cap) from being laid out on every frame.
    public static let maxLength = 400

    /// The first line of prose, cleaned. Code fences (``` or ~~~, and everything inside them),
    /// table rows and horizontal rules are skipped. Nil when nothing usable is left.
    public static func summary(_ raw: String) -> String? {
        var fence: String?   // the marker that opened the current fence; only it closes it
        for line in raw.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let open = fence {
                if trimmed.hasPrefix(open) { fence = nil }
                continue
            }
            if let marker = ["```", "~~~"].first(where: { trimmed.hasPrefix($0) }) {
                fence = marker
                continue
            }
            if trimmed.hasPrefix("|") || isRule(trimmed) { continue }
            let cleaned = clean(String(trimmed.prefix(maxLength * 4)))
            if !cleaned.isEmpty { return String(cleaned.prefix(maxLength)) }
        }
        return nil
    }

    /// `---`, `***`, `___`, `===`, with or without spaces between.
    static func isRule(_ line: String) -> Bool {
        let marks = line.filter { !$0.isWhitespace }
        guard marks.count >= 3, let first = marks.first, "-*_=".contains(first) else { return false }
        return marks.allSatisfy { $0 == first }
    }

    static func clean(_ line: String) -> String {
        var s = line
        s = s.replacingOccurrences(of: #"\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^(#{1,6}\s+|[-*+]\s+|\d+[.)]\s+|>\s*)"#, with: "", options: .regularExpression)
        // Emphasis comes off only where a pair of stars wraps text, so 2*3 and 2**3 survive.
        // `__` is left alone: Claude bolds with `**`, and stripping it turned __init__ into init.
        s = s.replacingOccurrences(of: #"(?<!\w)\*\*(?=\S)(.+?)(?<=\S)\*\*(?!\w)"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?<![\w*])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![\w*])"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: "`", with: "")
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespaces)
    }
}
