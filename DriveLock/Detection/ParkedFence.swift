import CoreLocation

/// A ~150 m ring around where the phone last was before a drive. Leaving it wakes the app,
/// usually within the first block, instead of waiting for a significant-change wake (~500 m).
/// Until a drive starts, the app drops a fresh ring at each new fix, so wakes keep coming
/// every ~150 m. iOS relaunches the app for these events even if it was terminated.
@MainActor
final class ParkedFence {
    var onExit: (() -> Void)?
    var onEvent: ((String) -> Void)?
    static let radius: CLLocationDistance = 150
    private static let monitorName = "DriveLockParkedFence"
    private static let id = "parked"

    private var monitor: CLMonitor?
    private var pending: CLLocation?
    private(set) var center: CLLocation?

    /// Call at launch, every launch: iOS hands queued exit events to the monitor with this name.
    func start() {
        Task {
            let m = await CLMonitor(Self.monitorName)
            monitor = m
            if let p = pending { pending = nil; await place(p, on: m) }
            do {
                for try await event in await m.events where event.identifier == Self.id {
                    if event.state == .unsatisfied {
                        onEvent?("LEFT parked fence")
                        onExit?()
                    }
                }
            } catch {
                onEvent?("fence events stopped: \(error.localizedDescription)")
            }
        }
    }

    /// Move the ring here, unless it's already centered within 50 m.
    func place(at loc: CLLocation) {
        if let c = center, c.distance(from: loc) < 50 { return }
        guard let m = monitor else { pending = loc; return }
        Task { await place(loc, on: m) }
    }

    private func place(_ loc: CLLocation, on m: CLMonitor) async {
        center = loc
        await m.remove(Self.id)
        await m.add(CLMonitor.CircularGeographicCondition(center: loc.coordinate, radius: Self.radius),
                    identifier: Self.id, assuming: .satisfied)
        onEvent?(String(format: "fence set (±%.0f m fix)", loc.horizontalAccuracy))
    }
}
