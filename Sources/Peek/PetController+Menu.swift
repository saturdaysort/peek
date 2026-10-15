import AppKit
import PeekCore

extension PetController {
    func installMenu() {
        view.menuProvider = { [weak self] in self?.makeMenu() }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(ClosureMenuItem("Dismiss") { [weak self] in self?.perform { $0.dismissCurrent() } })
        menu.addItem(ClosureMenuItem("Dismiss all") { [weak self] in self?.perform { $0.dismissAll() } })
        menu.addItem(.separator())
        if director.isQuiet(at: Date()) {
            menu.addItem(ClosureMenuItem("End quiet hour") { [weak self] in self?.endQuietHour() })
        } else {
            menu.addItem(ClosureMenuItem("Quiet for 1 hour") { [weak self] in self?.startQuietHour() })
        }
        menu.addItem(ClosureMenuItem("Sound", checked: Settings.soundOn) {
            Settings.soundOn.toggle()
            if Settings.soundOn { Chirp.play() }   // a preview, so you know what you turned on
        })
        menu.addItem(ClosureMenuItem("Open at login", checked: Settings.openAtLogin) {
            Settings.openAtLogin.toggle()
            LoginItem.apply()
        })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Quit Peek") { NSApp.terminate(nil) })
        return menu
    }

    func startQuietHour() {
        let until = Date().addingTimeInterval(3600)
        Settings.quietUntil = until
        perform { $0.startQuiet(until: until) }
        scheduleQuietEnd()
    }

    func endQuietHour() {
        quietTimer?.invalidate()
        quietTimer = nil
        Settings.quietUntil = nil
        perform { $0.quietEnded() }
    }

    /// Arms a timer for the end of the quiet hour, including one that survived a relaunch.
    func scheduleQuietEnd() {
        quietTimer?.invalidate()
        quietTimer = nil
        guard let until = director.quietUntil else { return }
        let delay = until.timeIntervalSinceNow
        guard delay > 0 else {
            endQuietHour()
            return
        }
        quietTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.endQuietHour()
        }
    }
}
