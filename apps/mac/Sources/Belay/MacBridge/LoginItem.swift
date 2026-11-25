import ServiceManagement

/// Open Belay at login through macOS's own login items (SMAppService, macOS 13+). macOS may ask the user to approve
/// it in System Settings → General → Login Items; `status` says so, and Settings shows it.
@MainActor
enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    /// Returns an error line for Settings, or nil.
    static func set(_ on: Bool) -> String? {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return on ? "macOS didn't add Belay to Login Items: \(error.localizedDescription)"
                      : "macOS didn't remove Belay from Login Items: \(error.localizedDescription)"
        }
    }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
