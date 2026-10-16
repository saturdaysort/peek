import Foundation

/// Unread messages, oldest first, at most one per session.
public struct MessageQueue: Sendable, Equatable {
    public static let capacity = 20

    public private(set) var items: [Message] = []
    /// Which message the bubble is showing.
    public private(set) var currentIndex = 0

    public init() {}

    public var isEmpty: Bool { items.isEmpty }
    public var count: Int { items.count }
    public var current: Message? { items.indices.contains(currentIndex) ? items[currentIndex] : nil }

    /// Adds a message, or replaces the same session's older one in place. Returns its index.
    @discardableResult
    public mutating func upsert(_ message: Message) -> Int {
        if let i = items.firstIndex(where: { $0.hostSessionId == message.hostSessionId }) {
            items[i] = message
            return i
        }
        items.append(message)
        if items.count > Self.capacity {
            items.removeFirst()
            currentIndex = max(0, currentIndex - 1)
        }
        return items.count - 1
    }

    public mutating func remove(sessionId: String) {
        guard let i = items.firstIndex(where: { $0.hostSessionId == sessionId }) else { return }
        items.remove(at: i)
        if i < currentIndex { currentIndex -= 1 }
        clamp()
    }

    public mutating func removeAll() {
        items.removeAll()
        currentIndex = 0
    }

    public mutating func show(index: Int) {
        currentIndex = index
        clamp()
    }

    public mutating func showOldest() {
        currentIndex = 0
    }

    /// The "Next >" button: one step forward, wrapping from the newest back to the oldest.
    public mutating func next() {
        guard !items.isEmpty else { return }
        currentIndex = (currentIndex + 1) % items.count
    }

    /// Moves through the queue, stopping at either end.
    public mutating func step(_ delta: Int) {
        currentIndex += delta
        clamp()
    }

    private mutating func clamp() {
        currentIndex = items.isEmpty ? 0 : min(max(currentIndex, 0), items.count - 1)
    }
}
