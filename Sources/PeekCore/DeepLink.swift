import Foundation

/// The Claude Desktop URL that opens a Code session.
///
/// Found in Claude Desktop 2.37337.1's URL handler (app.asar); not documented by Anthropic.
/// `claude://code/continue?session=<id>` opens the non-archived session with that id and falls
/// back to the Code home screen otherwise. Claude checks the id against
/// ^local_[A-Za-z0-9-]{1,64}$ and so do we, so nothing read from the inbox can become an
/// arbitrary URL.
public enum DeepLink {
    public static func isValidSessionId(_ id: String) -> Bool {
        guard id.hasPrefix("local_") else { return false }
        let rest = id.dropFirst("local_".count)
        return (1...64).contains(rest.count)
            && rest.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
    }

    public static func url(for hostSessionId: String) -> URL? {
        guard isValidSessionId(hostSessionId) else { return nil }
        return URL(string: "claude://code/continue?session=\(hostSessionId)")
    }
}
