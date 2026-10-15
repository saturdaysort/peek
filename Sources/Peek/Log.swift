import os

/// Peek's log lines. Read them with:
///   /usr/bin/log show --last 5m --style compact --predicate 'subsystem == "dev.longbrook.peek"'
/// (Use the full path: in zsh, `log` is a builtin.) NSLog isn't used because its text shows up
/// as <private> in the unified log on this macOS, which makes it useless for troubleshooting.
enum Log {
    private static let logger = Logger(subsystem: "dev.longbrook.peek", category: "app")

    static func info(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }
}
