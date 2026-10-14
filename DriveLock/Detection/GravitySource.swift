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
            guard let g = motion?.gravity else { return }
            let now = Date()
            self?.onSample?(GravitySample(time: now.timeIntervalSinceReferenceDate, x: g.x, y: g.y, z: g.z), now)
        }
    }

    func stop() { manager.stopDeviceMotionUpdates() }
}
