import Foundation
import Testing
@testable import PeekCore

private func msg(_ name: String, _ text: String = "t") -> Message {
    Message(hostSessionId: "local_\(name)", kind: .done, title: name, text: text, receivedAt: .distantPast)
}

@Suite struct MessageQueueTests {
    @Test func keepsArrivalOrder() {
        var q = MessageQueue()
        for name in ["a", "b", "c"] { q.upsert(msg(name)) }
        #expect(q.items.map(\.title) == ["a", "b", "c"])
        #expect(q.current == msg("a"))
    }

    @Test func upsertReturnsTheIndex() {
        var q = MessageQueue()
        #expect(q.upsert(msg("a")) == 0)
        #expect(q.upsert(msg("b")) == 1)
        #expect(q.upsert(msg("a", "again")) == 0)
    }

    @Test func sameSessionReplacesInPlace() {
        var q = MessageQueue()
        q.upsert(msg("a", "old"))
        q.upsert(msg("b"))
        q.upsert(msg("a", "new"))
        #expect(q.items.map(\.title) == ["a", "b"])
        #expect(q.items[0].text == "new")
    }

    @Test func capacityDropsTheOldest() {
        var q = MessageQueue()
        for i in 0..<25 { q.upsert(msg("s\(i)")) }
        #expect(q.count == MessageQueue.capacity)
        #expect(q.items.first?.title == "s5")
    }

    @Test func removingAnEarlierMessageKeepsTheSameCurrent() {
        var q = MessageQueue()
        for name in ["a", "b", "c"] { q.upsert(msg(name)) }
        q.show(index: 2)
        q.remove(sessionId: "local_a")
        #expect(q.current == msg("c"))
    }

    @Test func removingTheLastClampsToTheNewLast() {
        var q = MessageQueue()
        q.upsert(msg("a"))
        q.upsert(msg("b"))
        q.show(index: 1)
        q.remove(sessionId: "local_b")
        #expect(q.current == msg("a"))
    }

    @Test func stepStopsAtTheEnds() {
        var q = MessageQueue()
        for name in ["a", "b", "c"] { q.upsert(msg(name)) }
        q.step(5)
        #expect(q.current == msg("c"))
        q.step(-9)
        #expect(q.current == msg("a"))
    }

    @Test func nextWrapsToTheOldest() {
        var q = MessageQueue()
        for name in ["a", "b"] { q.upsert(msg(name)) }
        q.next()
        #expect(q.current == msg("b"))
        q.next()
        #expect(q.current == msg("a"))
        var empty = MessageQueue()
        empty.next()
        #expect(empty.current == nil)
    }

    @Test func emptyQueueIsSafe() {
        var q = MessageQueue()
        q.step(1)
        q.remove(sessionId: "local_x")
        q.showOldest()
        #expect(q.current == nil)
        #expect(q.isEmpty)
    }
}
