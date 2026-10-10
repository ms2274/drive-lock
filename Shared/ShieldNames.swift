import DeviceActivity
import ManagedSettings

/// Names shared by the app and the DriveLockMonitor extension.
enum AppGroup {
    static let id = "group.com.michaelscardena.drivelock"
}

extension ManagedSettingsStore.Name {
    /// The one store DriveLock writes shields into.
    static let driving = Self("driving")
}

extension DeviceActivityName {
    /// Safety window: if it ends while shields are up, the extension clears them.
    static let driveSafety = Self("driveSafety")
}
