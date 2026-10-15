import Foundation

/// Preferences, persisted in UserDefaults (domain dev.longbrook.peek).
enum Settings {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: ["soundOn": false, "openAtLogin": true])
    }

    static var soundOn: Bool {
        get { defaults.bool(forKey: "soundOn") }
        set { defaults.set(newValue, forKey: "soundOn") }
    }

    static var openAtLogin: Bool {
        get { defaults.bool(forKey: "openAtLogin") }
        set { defaults.set(newValue, forKey: "openAtLogin") }
    }

    /// End of the current quiet hour; survives a relaunch.
    static var quietUntil: Date? {
        get { defaults.object(forKey: "quietUntil") as? Date }
        set { defaults.set(newValue, forKey: "quietUntil") }
    }
}
