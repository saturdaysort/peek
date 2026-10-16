import Foundation

/// The pet's behavior, with no AppKit and no clock. The app feeds it inputs (a message arrived,
/// an animation finished, the bubble timed out, a click) and performs the effects it returns.
public struct Director: Sendable {
    public enum Phase: Sendable, Equatable {
        case hidden, entering, showing, peeking, leaving
    }

    public enum Animation: Sendable, Equatable {
        /// Scuttle in from the right edge, then one hop (done) or two bounces (needs you).
        case enter(MessageKind)
        /// Scuttle in already ducked: a quiet hour ended with unread messages.
        case enterPeeking
        case hop
        case duck
        case unduck
        case leave
    }

    public enum Effect: Sendable, Equatable {
        case animate(Animation)
        case open(URL)
        case chirp
        case restartBubbleTimer
    }

    /// The "1 of 3" counter and "Next >" button in the bubble, when more than one message waits.
    public struct Pager: Sendable, Equatable {
        public static let nextTitle = "Next >"

        public let position: Int
        public let total: Int

        public init(position: Int, total: Int) {
            self.position = position
            self.total = total
        }

        public var label: String { "\(position) of \(total)" }
    }

    public static let greetingTitle = "Peek"
    public static let greetingText = "Nothing new"

    public private(set) var phase: Phase = .hidden
    public private(set) var queue = MessageQueue()
    /// True while the bubble is saying "Nothing new" after you opened Peek by hand.
    public private(set) var isGreeting = false
    public private(set) var quietUntil: Date?

    public init(quietUntil: Date? = nil) {
        self.quietUntil = quietUntil
    }

    public func isQuiet(at now: Date) -> Bool {
        quietUntil.map { now < $0 } ?? false
    }

    /// What the bubble says, when it is out.
    public var bubbleMessage: Message? {
        guard phase == .showing else { return nil }
        if isGreeting {
            return Message(hostSessionId: "", kind: .done, title: Self.greetingTitle,
                           text: Self.greetingText, receivedAt: .distantPast)
        }
        return queue.current
    }

    /// Only while peeking, when it is the only sign of what's unread. With the bubble out, the
    /// pager's counter says the same thing more clearly.
    public var badgeCount: Int {
        phase == .peeking ? queue.count : 0
    }

    /// Counter and Next button for the bubble; nil unless it is out with two or more messages.
    public var pager: Pager? {
        guard phase == .showing, !isGreeting, queue.count > 1 else { return nil }
        return Pager(position: queue.currentIndex + 1, total: queue.count)
    }

    // MARK: Inputs

    public mutating func receive(_ message: Message, now: Date) -> [Effect] {
        let index = queue.upsert(message)
        if isQuiet(at: now) { return [] }
        switch phase {
        case .hidden, .leaving:
            isGreeting = false
            queue.show(index: index)
            phase = .entering
            return [.chirp, .animate(.enter(message.kind))]
        case .peeking:
            queue.show(index: index)
            phase = .showing
            return [.chirp, .animate(.unduck), .restartBubbleTimer]
        case .entering:
            if isGreeting {
                isGreeting = false
                queue.show(index: index)
            }
            return [.chirp]
        case .showing:
            if !isGreeting {
                // Never interrupt a message being read, but a newer one from the same session
                // replaced it in place: give it the full 10 seconds.
                return index == queue.currentIndex ? [.chirp, .restartBubbleTimer] : [.chirp]
            }
            isGreeting = false
            queue.show(index: index)
            return [.chirp, .animate(.hop), .restartBubbleTimer]
        }
    }

    public mutating func entranceFinished() -> [Effect] {
        guard phase == .entering else { return [] }
        phase = .showing
        return [.restartBubbleTimer]
    }

    public mutating func bubbleTimedOut() -> [Effect] {
        guard phase == .showing else { return [] }
        if isGreeting || queue.isEmpty { return leave() }
        phase = .peeking
        return [.animate(.duck)]
    }

    public mutating func clicked() -> [Effect] {
        switch phase {
        case .peeking:
            queue.showOldest()
            phase = .showing
            return [.animate(.unduck), .restartBubbleTimer]
        case .entering, .showing:
            if isGreeting { return leave() }
            guard let current = queue.current else { return leave() }
            queue.remove(sessionId: current.hostSessionId)
            let open: [Effect] = DeepLink.url(for: current.hostSessionId).map { [.open($0)] } ?? []
            return open + afterRemoval()
        case .hidden, .leaving:
            return []
        }
    }

    /// The bubble's "Next >" button: show the next message (wrapping) without opening anything.
    public mutating func next() -> [Effect] {
        guard pager != nil else { return [] }
        queue.next()
        return [.restartBubbleTimer]
    }

    public mutating func scroll(by delta: Int) -> [Effect] {
        guard phase == .showing, !isGreeting else { return [] }
        let before = queue.currentIndex
        queue.step(delta)
        return queue.currentIndex == before ? [] : [.restartBubbleTimer]
    }

    public mutating func dismissCurrent() -> [Effect] {
        switch phase {
        case .entering, .showing:
            if isGreeting { return leave() }
            if let current = queue.current { queue.remove(sessionId: current.hostSessionId) }
            return afterRemoval()
        case .peeking:
            if let current = queue.current { queue.remove(sessionId: current.hostSessionId) }
            queue.showOldest()
            return queue.isEmpty ? leave() : []
        case .hidden, .leaving:
            return []
        }
    }

    public mutating func dismissAll() -> [Effect] {
        queue.removeAll()
        isGreeting = false
        return phase == .hidden || phase == .leaving ? [] : leave()
    }

    public mutating func leaveFinished() -> [Effect] {
        guard phase == .leaving else { return [] }
        phase = .hidden
        isGreeting = false
        return []
    }

    /// You opened Peek by hand: come out with the queue, or say there's nothing new.
    public mutating func greet() -> [Effect] {
        switch phase {
        case .hidden, .leaving:
            isGreeting = queue.isEmpty
            queue.showOldest()
            phase = .entering
            return [.animate(.enter(.done))]
        case .peeking:
            return clicked()
        case .entering, .showing:
            return []
        }
    }

    public mutating func startQuiet(until: Date) -> [Effect] {
        quietUntil = until
        isGreeting = false
        return phase == .hidden || phase == .leaving ? [] : leave()
    }

    public mutating func quietEnded() -> [Effect] {
        quietUntil = nil
        // Mid-exit counts as gone: the hour may have started by sending the pet off, and letting
        // it finish leaving would strand the unread messages offstage.
        guard phase == .hidden || phase == .leaving, !queue.isEmpty else { return [] }
        isGreeting = false
        queue.showOldest()
        phase = .peeking
        return [.animate(.enterPeeking)]
    }

    // MARK: Helpers

    private mutating func afterRemoval() -> [Effect] {
        queue.showOldest()
        guard !queue.isEmpty else { return leave() }
        phase = .showing
        return [.animate(.hop), .restartBubbleTimer]
    }

    private mutating func leave() -> [Effect] {
        phase = .leaving
        return [.animate(.leave)]
    }
}
