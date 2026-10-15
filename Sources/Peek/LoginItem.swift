import Foundation
import ServiceManagement

/// Open at login, through SMAppService (macOS 13+). Peek is ad-hoc signed; the status logged
/// here (0 not registered, 1 enabled, 2 requires approval, 3 not found) is the first thing
/// to check if it stops launching at login.
enum LoginItem {
    static func apply() {
        let service = SMAppService.mainApp
        do {
            if Settings.openAtLogin, service.status != .enabled {
                try service.register()
            } else if !Settings.openAtLogin, service.status == .enabled {
                try service.unregister()
            }
        } catch {
            Log.info("login item change failed: \(error.localizedDescription)")
        }
        Log.info("login item status \(service.status.rawValue)")
    }
}
