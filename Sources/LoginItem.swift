import Foundation
import ServiceManagement

/// Launch-at-login, via `SMAppService` (macOS 13+).
///
/// `isEnabled` reads back the real state rather than caching a preference, so the menu
/// never claims to be on after the user has revoked it in System Settings.
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns true if the resulting state matches what was asked for.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return isEnabled == enabled
        } catch {
            NSLog("[LoginItem] \(enabled ? "register" : "unregister") failed: \(error)")
            return false
        }
    }

    /// Human-readable state for the menu, including the case where macOS is waiting for
    /// the user to approve the item in System Settings.
    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:         return "on"
        case .notRegistered:   return "off"
        case .requiresApproval: return "needs approval in System Settings"
        case .notFound:        return "unavailable"
        @unknown default:      return "unknown"
        }
    }
}
