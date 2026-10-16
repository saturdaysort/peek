import AppKit
import PeekCore

/// Connects the pure Director to the screen. It owns the panel and a 60 Hz clock that runs only
/// while the pet is visible, performs the Director's effects, and feeds it the time-based inputs
/// (an animation finished, the bubble timed out).
final class PetController {
    static let claudeBundleId = "com.anthropic.claudefordesktop"

    private(set) var director: Director
    let panel = PetPanel()
    let view = PetView(frame: NSRect(origin: .zero, size: PetPanel.size))
    var quietTimer: Timer?

    private let sessions = SessionDirectory.claudeDefault
    private var clock: Timer?
    private var lastTick = 0.0
    private var motion: Motion?
    private var motionStart = 0.0
    private var pose = Pose.offstage
    private var bubbleRemaining = Timing.bubbleStays
    private var shownMessage: Message?
    private var shownAt = 0.0
    /// Set while a peek walks off one screen to reappear on the screen you moved to.
    private var relocatingTo: NSScreen?
    private var lastFollowCheck = 0.0

    init(quietUntil: Date? = nil) {
        director = Director(quietUntil: quietUntil)
        panel.contentView = view
        // Clicks are ignored for the moment a peek is walking off to another screen.
        view.onClick = { [weak self] in
            guard let self, self.relocatingTo == nil else { return }
            self.perform { $0.clicked() }
        }
        view.onNext = { [weak self] in
            guard let self, self.relocatingTo == nil else { return }
            self.perform { $0.next() }
        }
        view.onScroll = { [weak self] delta in self?.perform { $0.scroll(by: delta) } }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.panel.reanchor()
        }
    }

    // MARK: Inputs

    func receive(_ events: [PeekEvent]) {
        let focusedId = isClaudeFrontmost ? sessions.mostRecentlyFocusedId() : nil
        for event in events {
            if event.hostSessionId == focusedId {
                // Courtesy rule: Claude is in front showing this session already.
                Log.info("skipped event for the focused session \(event.hostSessionId)")
                continue
            }
            let title = SessionDirectory.displayTitle(info: sessions.info(for: event.hostSessionId), cwd: event.cwd)
            let message = Message(event: event, title: title)
            followNow()
            perform { $0.receive(message, now: Date()) }
        }
    }

    func greet() {
        followNow()
        perform { $0.greet() }
    }

    func perform(_ input: (inout Director) -> [Director.Effect]) {
        for effect in input(&director) {
            switch effect {
            case .animate(let animation): start(animation)
            case .open(let url): NSWorkspace.shared.open(url)
            case .chirp: if Settings.soundOn { Chirp.play() }
            case .restartBubbleTimer: bubbleRemaining = Timing.bubbleStays
            }
        }
        if director.phase != .hidden { startClock() }
    }

    private var isClaudeFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.claudeBundleId
    }

    // MARK: Clock

    private var now: Double { ProcessInfo.processInfo.systemUptime }

    private func start(_ animation: Director.Animation) {
        if let target = relocatingTo {
            relocatingTo = nil
            if animation != .leave {
                // The pet is needed now (a message arrived mid-move): skip the rest of the walk.
                panel.anchor(to: target)
                pose = Pose(x: 0, y: -Geometry.duckDepth)
            }
        }
        beginMotion(animation)
        if !panel.isVisible {
            if let screen = ActiveScreen.current() { panel.anchor(to: screen) }
            panel.orderFrontRegardless()
        }
    }

    private func beginMotion(_ animation: Director.Animation) {
        motion = Motion(animation, from: pose)
        motionStart = now
        if clock != nil { scheduleClock(every: Timing.tickInterval(phase: director.phase, animating: true)) }
    }

    // MARK: Following you between screens

    /// A peek that's just sitting on the wrong screen walks off and reappears on yours.
    private func followIfNeeded(at t: Double) {
        guard t - lastFollowCheck >= 1, relocatingTo == nil else { return }
        lastFollowCheck = t
        guard let active = ActiveScreen.current(),
              ScreenPicker.shouldFollow(phase: director.phase, animating: motion != nil,
                                        petScreen: panel.screenID, activeScreen: active.displayID) else { return }
        relocatingTo = active
        beginMotion(.leave)
    }

    /// Before the pet pops up out of a peek for a new message or a greeting: if it's sitting on
    /// a screen you've left, put it on yours first, since the walk-over would only delay the news.
    private func followNow() {
        guard director.phase == .peeking, motion == nil, relocatingTo == nil,
              let active = ActiveScreen.current(), active.displayID != panel.screenID else { return }
        panel.anchor(to: active)
        pose = Pose(x: 0, y: -Geometry.duckDepth)
    }

    private func finishRelocation(to screen: NSScreen) {
        relocatingTo = nil
        panel.anchor(to: screen)
        pose = Pose(x: Geometry.offstage, y: -Geometry.duckDepth)
        beginMotion(.enterPeeking)
    }

    private func startClock() {
        guard clock == nil else { return }
        lastTick = now
        scheduleClock(every: Timing.tickInterval(phase: director.phase, animating: motion != nil))
    }

    private func scheduleClock(every interval: Double) {
        if let clock, clock.timeInterval == interval { return }
        clock?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
    }

    private func tick() {
        let t = now
        let dt = t - lastTick
        lastTick = t

        if let m = motion {
            pose = m.pose(at: t - motionStart)
            if m.isFinished(at: t - motionStart) {
                motion = nil
                switch m.animation {
                case .enter, .enterPeeking: perform { $0.entranceFinished() }
                case .leave:
                    if let target = relocatingTo { finishRelocation(to: target) } else { perform { $0.leaveFinished() } }
                case .hop, .duck, .unduck: break
                }
            }
        }

        // The bubble's countdown pauses while the pointer is over the pet or the bubble, and while
        // the right-click menu is open (the pointer is then usually on the menu, not the pet).
        let hovering = view.containsMouse
        if director.phase == .showing, motion == nil, !hovering, !view.isMenuOpen {
            bubbleRemaining -= dt
            if bubbleRemaining <= 0 { perform { $0.bubbleTimedOut() } }
        }

        followIfNeeded(at: t)
        render(at: t)
        panel.ignoresMouseEvents = !hovering   // clicks anywhere else fall through to the app below

        if director.phase == .hidden {
            clock?.invalidate()
            clock = nil
            motion = nil
            pose = .offstage
            panel.orderOut(nil)
        } else {
            // Drop to a slow tick while the pet just peeks; any new animation speeds it back up.
            scheduleClock(every: Timing.tickInterval(phase: director.phase, animating: motion != nil))
        }
    }

    private func render(at t: Double) {
        let bubble = director.bubbleMessage
        if bubble != shownMessage {
            shownMessage = bubble
            shownAt = t
        }
        let age = t - shownAt
        view.state = PetView.State(
            pose: pose,
            stride: pose.walking && Int(t / Timing.legFrame) % 2 == 1,
            blinking: t.truncatingRemainder(dividingBy: Timing.blinkEvery) < Timing.blinkFor,
            bubble: bubble,
            revealed: bubble.map { Int(Double($0.text.count) * min(1, age / Timing.typeOn)) } ?? 0,
            popScale: min(1, (age / Timing.bubblePop * 4).rounded(.up) / 4),
            bangOn: Int(t / Timing.bangBlink) % 2 == 0,
            badge: director.badgeCount,
            pager: director.pager,
            nextHovered: view.isMouseOverNext
        )
    }
}
