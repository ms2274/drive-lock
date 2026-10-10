import DeviceActivity
import ManagedSettings

/// Clears shields if the app stopped renewing the safety window (e.g. iOS killed it mid-drive).
final class DriveSafetyMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .driveSafety else { return }
        ManagedSettingsStore(named: .driving).clearAllSettings()
    }
}
