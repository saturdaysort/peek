import Foundation
import Testing
@testable import PeekCore

private let now = Date(timeIntervalSince1970: 1_792_086_557)

private func msg(_ name: String, _ text: String = "Done", kind: MessageKind = .done) -> Message {
    Message(hostSessionId: "local_\(name)", kind: kind, title: name, text: text, receivedAt: now)
}

private func url(_ name: String) -> URL { DeepLink.url(for: "local_\(name)")! }

/// A Director that has finished walking in and is showing the first message.
private func showing(_ messages: Message...) -> Director {
    var d = Director()
    for m in messages { _ = d.receive(m, now: now) }
    _ = d.entranceFinished()
    return d
}

@Suite struct DirectorTests {
    @Test func arrivalWhenHiddenWalksIn() {
        var d = Director()
        #expect(d.receive(msg("a"), now: now) == [.chirp, .animate(.enter(.done))])
        #expect(d.phase == .entering)
        #expect(d.bubbleMessage == nil)
    }

    @Test func needsYouHasItsOwnEntrance() {
        var d = Director()
        #expect(d.receive(msg("a", kind: .needsYou), now: now) == [.chirp, .animate(.enter(.needsYou))])
    }

    @Test func finishingTheEntranceShowsTheBubble() {
        var d = Director()
        _ = d.receive(msg("a"), now: now)
        #expect(d.entranceFinished() == [.restartBubbleTimer])
        #expect(d.phase == .showing)
        #expect(d.bubbleMessage == msg("a"))
        #expect(d.badgeCount == 0)
    }

    @Test func arrivalWhileShowingWaitsItsTurn() {
        var d = showing(msg("a"))
        #expect(d.receive(msg("b"), now: now) == [.chirp])
        #expect(d.bubbleMessage == msg("a"))
        #expect(d.badgeCount == 1)
    }

    @Test func timeoutDucksToAPeek() {
        var d = showing(msg("a"))
        #expect(d.bubbleTimedOut() == [.animate(.duck)])
        #expect(d.phase == .peeking)
        #expect(d.bubbleMessage == nil)
        #expect(d.badgeCount == 1)
    }

    @Test func clickingThePeekShowsTheOldest() {
        var d = showing(msg("a"), msg("b"))
        _ = d.scroll(by: 1)
        _ = d.bubbleTimedOut()
        #expect(d.clicked() == [.animate(.unduck), .restartBubbleTimer])
        #expect(d.bubbleMessage == msg("a"))
    }

    @Test func arrivalWhilePeekingPopsUpWithTheNewOne() {
        var d = showing(msg("a"))
        _ = d.bubbleTimedOut()
        #expect(d.receive(msg("b"), now: now) == [.chirp, .animate(.unduck), .restartBubbleTimer])
        #expect(d.bubbleMessage == msg("b"))
        #expect(d.badgeCount == 1)
    }

    @Test func clickOpensTheSessionThenShowsTheNext() {
        var d = showing(msg("a"), msg("b"))
        #expect(d.clicked() == [.open(url("a")), .animate(.hop), .restartBubbleTimer])
        #expect(d.bubbleMessage == msg("b"))
        #expect(d.queue.count == 1)
    }

    @Test func clickOnTheLastMessageOpensAndLeaves() {
        var d = showing(msg("a"))
        #expect(d.clicked() == [.open(url("a")), .animate(.leave)])
        #expect(d.phase == .leaving)
        #expect(d.leaveFinished() == [])
        #expect(d.phase == .hidden)
    }

    @Test func clickWhileWalkingInOpensThatSession() {
        var d = Director()
        _ = d.receive(msg("a"), now: now)
        #expect(d.clicked() == [.open(url("a")), .animate(.leave)])
    }

    @Test func sameSessionReplacesItsMessage() {
        var d = showing(msg("a", "old"))
        _ = d.receive(msg("a", "new"), now: now)
        #expect(d.bubbleMessage?.text == "new")
        #expect(d.queue.count == 1)
    }

    @Test func replacingTheMessageBeingReadRestartsItsCountdown() {
        var d = showing(msg("a", "old"), msg("b"))
        #expect(d.receive(msg("a", "new"), now: now) == [.chirp, .restartBubbleTimer])
        #expect(d.receive(msg("b", "newer"), now: now) == [.chirp])   // not on screen: no restart
    }

    @Test func scrollFlipsWithoutOpening() {
        var d = showing(msg("a"), msg("b"), msg("c"))
        #expect(d.scroll(by: 1) == [.restartBubbleTimer])
        #expect(d.bubbleMessage == msg("b"))
        _ = d.scroll(by: 5)
        #expect(d.bubbleMessage == msg("c"))
        #expect(d.scroll(by: 1) == [])
    }

    @Test func dismissRemovesWithoutOpening() {
        var d = showing(msg("a"), msg("b"))
        #expect(d.dismissCurrent() == [.animate(.hop), .restartBubbleTimer])
        #expect(d.bubbleMessage == msg("b"))
    }

    @Test func dismissWhilePeekingStaysPeekingUntilEmpty() {
        var d = showing(msg("a"), msg("b"))
        _ = d.bubbleTimedOut()
        #expect(d.dismissCurrent() == [])
        #expect(d.phase == .peeking)
        #expect(d.dismissCurrent() == [.animate(.leave)])
    }

    @Test func dismissAllEmptiesAndLeaves() {
        var d = showing(msg("a"), msg("b"))
        #expect(d.dismissAll() == [.animate(.leave)])
        #expect(d.queue.isEmpty)
    }

    @Test func quietHourQueuesSilentlyThenPeeks() {
        var d = Director()
        #expect(d.startQuiet(until: now.addingTimeInterval(3600)) == [])
        #expect(d.receive(msg("a"), now: now) == [])
        #expect(d.phase == .hidden)
        #expect(d.quietEnded() == [.animate(.enterPeeking)])
        #expect(d.phase == .peeking)
        #expect(d.badgeCount == 1)
    }

    @Test func quietHourEndsSilentlyWhenNothingArrived() {
        var d = Director()
        _ = d.startQuiet(until: now.addingTimeInterval(3600))
        #expect(d.quietEnded() == [])
        #expect(d.phase == .hidden)
    }

    @Test func quietHourEndingMidExitPeeksInsteadOfHiding() {
        var d = showing(msg("a"))
        _ = d.startQuiet(until: now.addingTimeInterval(3600))
        #expect(d.phase == .leaving)
        #expect(d.quietEnded() == [.animate(.enterPeeking)])
        #expect(d.phase == .peeking)
        #expect(d.badgeCount == 1)
    }

    @Test func quietHourEndingMidGreetingExitShowsTheMessageNotTheGreeting() {
        var d = Director()
        _ = d.startQuiet(until: now.addingTimeInterval(3600))
        _ = d.greet()
        _ = d.entranceFinished()
        _ = d.receive(msg("a"), now: now)   // queued silently under the greeting
        _ = d.clicked()                      // dismisses the greeting: walking out
        _ = d.quietEnded()
        _ = d.clicked()
        #expect(d.bubbleMessage == msg("a"))
    }

    @Test func startingQuietWhileShowingLeavesButKeepsTheQueue() {
        var d = showing(msg("a"))
        #expect(d.startQuiet(until: now.addingTimeInterval(3600)) == [.animate(.leave)])
        #expect(d.queue.count == 1)
    }

    @Test func greetingWhenEmptySaysNothingNew() {
        var d = Director()
        #expect(d.greet() == [.animate(.enter(.done))])
        _ = d.entranceFinished()
        #expect(d.bubbleMessage?.title == "Peek")
        #expect(d.bubbleMessage?.text == "Nothing new")
        #expect(d.badgeCount == 0)
        #expect(d.clicked() == [.animate(.leave)])
    }

    @Test func greetingTimesOutByLeaving() {
        var d = Director()
        _ = d.greet()
        _ = d.entranceFinished()
        #expect(d.bubbleTimedOut() == [.animate(.leave)])
    }

    @Test func arrivalDuringTheGreetingTakesOver() {
        var d = Director()
        _ = d.greet()
        _ = d.entranceFinished()
        #expect(d.receive(msg("a"), now: now) == [.chirp, .animate(.hop), .restartBubbleTimer])
        #expect(d.bubbleMessage == msg("a"))
    }

    @Test func greetingWithUnreadShowsTheOldest() {
        var d = Director()
        _ = d.startQuiet(until: now.addingTimeInterval(3600))
        _ = d.receive(msg("a"), now: now)
        _ = d.receive(msg("b"), now: now)
        #expect(d.greet() == [.animate(.enter(.done))])
        _ = d.entranceFinished()
        #expect(d.bubbleMessage == msg("a"))
    }

    @Test func arrivalWhileLeavingTurnsBack() {
        var d = showing(msg("a"))
        _ = d.clicked()
        #expect(d.receive(msg("b"), now: now) == [.chirp, .animate(.enter(.done))])
        #expect(d.phase == .entering)
    }

    @Test func burstMakesOneEntranceAndRespectsTheCap() {
        var d = Director()
        var entrances = 0
        for i in 0..<25 {
            entrances += d.receive(msg("s\(i)"), now: now).filter {
                if case .animate(.enter(_)) = $0 { true } else { false }
            }.count
        }
        #expect(entrances == 1)
        #expect(d.queue.count == MessageQueue.capacity)
    }

    @Test func unicodeSurvivesUnchanged() {
        let d = showing(Message(hostSessionId: "local_u", kind: .done, title: "café 完了",
                                text: "Déployé, 完了", receivedAt: now))
        #expect(d.bubbleMessage?.title == "café 完了")
        #expect(d.bubbleMessage?.text == "Déployé, 完了")
    }
}
