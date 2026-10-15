import Foundation

/// Why the pet is showing up.
public enum MessageKind: String, Sendable, Equatable {
    /// A session finished its turn (Claude Code `Stop` hook).
    case done
    /// A session is waiting on a permission or a question (`Notification` hook).
    case needsYou

    /// Bubble text when the hook gave us nothing usable.
    public var fallbackText: String {
        switch self {
        case .done: "Done"
        case .needsYou: "Needs you"
        }
    }
}

/// One hook event, as read from the inbox.
public struct PeekEvent: Sendable, Equatable {
    public let hostSessionId: String
    public let kind: MessageKind
    public let text: String
    public let cwd: String?
    public let receivedAt: Date

    public init(hostSessionId: String, kind: MessageKind, text: String, cwd: String?, receivedAt: Date) {
        self.hostSessionId = hostSessionId
        self.kind = kind
        self.text = text
        self.cwd = cwd
        self.receivedAt = receivedAt
    }
}

/// What a bubble shows: an event plus the session's display title.
public struct Message: Sendable, Equatable {
    public let hostSessionId: String
    public let kind: MessageKind
    public let title: String
    public let text: String
    public let receivedAt: Date

    public init(hostSessionId: String, kind: MessageKind, title: String, text: String, receivedAt: Date) {
        self.hostSessionId = hostSessionId
        self.kind = kind
        self.title = title
        self.text = text
        self.receivedAt = receivedAt
    }

    public init(event: PeekEvent, title: String) {
        self.init(hostSessionId: event.hostSessionId, kind: event.kind, title: title,
                  text: event.text, receivedAt: event.receivedAt)
    }
}
