import Foundation

/// Reads one inbox envelope: line 1 is the Desktop session id (CLAUDE_CODE_HOST_SESSION_ID),
/// the rest is the Claude Code hook's stdin JSON.
public enum EventParser {
    /// `idle_prompt` repeats a Stop we already showed; `auth_success` is not about a session.
    public static let ignoredNotificationTypes: Set<String> = ["idle_prompt", "auth_success"]

    public static func parse(_ data: Data, receivedAt: Date) -> PeekEvent? {
        guard let newline = data.firstIndex(of: 0x0A),
              let id = String(data: data[data.startIndex..<newline], encoding: .utf8),
              DeepLink.isValidSessionId(id) else { return nil }
        let body = Data(data[data.index(after: newline)...])
        guard let payload = (try? JSONDecoder().decode(HookPayload.self, from: body)) ?? HookPayload(salvaging: body)
        else { return nil }

        let kind: MessageKind
        let raw: String?
        switch payload.hook_event_name {
        case "Stop":
            kind = .done
            raw = payload.last_assistant_message
        case "Notification":
            if let type = payload.notification_type, ignoredNotificationTypes.contains(type) { return nil }
            kind = .needsYou
            raw = payload.message
        default:
            return nil
        }
        let text = raw.flatMap(TextTrimmer.summary) ?? kind.fallbackText
        return PeekEvent(hostSessionId: id, kind: kind, text: text, cwd: payload.cwd, receivedAt: receivedAt)
    }
}

/// The fields Peek uses from a Claude Code hook payload. Unknown fields are ignored.
struct HookPayload: Decodable {
    var hook_event_name: String
    var cwd: String?
    var last_assistant_message: String?
    var message: String?
    var notification_type: String?
}

extension HookPayload {
    /// For a payload the hook cut at its 1 MB cap: the event name and cwd come first in
    /// Claude Code's JSON, so recover them from the head and let the text fall back.
    init?(salvaging body: Data) {
        let head = String(decoding: body.prefix(4096), as: UTF8.self)
        guard let name = Self.field("hook_event_name", in: head) else { return nil }
        self.init(hook_event_name: name, cwd: Self.field("cwd", in: head), last_assistant_message: nil,
                  message: nil, notification_type: Self.field("notification_type", in: head))
    }

    static func field(_ key: String, in text: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"(?:[^\"\\\\]|\\\\.)*\""
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }
        let match = text[range]
        guard let colon = match.firstIndex(of: ":") else { return nil }
        let literal = match[match.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        return try? JSONDecoder().decode(String.self, from: Data(literal.utf8))
    }
}
