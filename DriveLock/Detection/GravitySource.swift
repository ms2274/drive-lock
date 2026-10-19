import CoreMotion

/// Thin wrapper over CMMotionManager device motion. Only runs during a drive.
final class GravitySource {
    private let manager = CMMotionManager()
    var onSample: ((GravitySample, Date) -> Void)?

    static var isAvailable: Bool { CMMotionManager().isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 0.1
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let m = motion else { return }
            // Use when the sample was measured, not when it reached us: after iOS lets the app
            // sleep, samples queued from before the sleep arrive in a burst, and stamping them all
            // "now" made the orientation change across the sleep look like a pickup.
            let measured = Date(timeIntervalSinceNow: m.timestamp - ProcessInfo.processInfo.systemUptime)
            guard Date().timeIntervalSince(measured) < 1 else { return }
            let g = m.gravity
            self?.onSample?(GravitySample(time: measured.timeIntervalSinceReferenceDate, x: g.x, y: g.y, z: g.z), measured)
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}
