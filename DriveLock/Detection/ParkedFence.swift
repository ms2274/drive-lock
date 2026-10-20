import CoreLocation

/// A ~150 m ring around where the phone sat before a drive. Leaving it should wake the app
/// sooner than a significant-change wake (~500 m).
///
/// Uses classic region monitoring. The first version used CLMonitor (iOS 17), but in the
/// 2026-10-19 drive logs it never woke the app on departure (0 of 7 drives); exits only
/// arrived while the app was already awake. Region monitoring is the long-proven way to have
/// iOS wake or relaunch an app on exit.
@MainActor
final class ParkedFence {
    static let radius: CLLocationDistance = 150
    private let location: LocationSource
    private(set) var center: CLLocation?

    init(location: LocationSource) { self.location = location }

    /// Stop the CLMonitor condition left behind by the earlier version.
    func removeOldMonitor() {
        Task {
            let m = await CLMonitor("DriveLockParkedFence")
            await m.remove("parked")
        }
    }

    /// Move the ring here, unless it's already centered within 50 m.
    func place(at loc: CLLocation) {
        if let c = center, c.distance(from: loc) < 50 { return }
        center = loc
        location.monitorFence(around: loc, radius: Self.radius)
    }
}
