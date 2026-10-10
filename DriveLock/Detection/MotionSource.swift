import CoreMotion

/// Thin wrapper over CMMotionActivityManager. Emits only automotive true/false.
final class MotionSource {
    private let manager = CMMotionActivityManager()
    var onAutomotive: ((Bool, Date) -> Void)?

    static var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }
    static var authorization: CMAuthorizationStatus { CMMotionActivityManager.authorizationStatus() }

    func start() {
        guard Self.isAvailable else { return }
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let a = activity, a.confidence != .low else { return }
            self?.onAutomotive?(a.automotive, a.startDate)
        }
    }

    func stop() { manager.stopActivityUpdates() }

    /// Called on background wake-ups to catch up on what happened while suspended.
    func recentAutomotive(since: Date, completion: @escaping (Bool) -> Void) {
        guard Self.isAvailable else { return completion(false) }
        manager.queryActivityStarting(from: since, to: Date(), to: .main) { acts, _ in
            completion(acts?.last(where: { $0.confidence != .low })?.automotive ?? false)
        }
    }
}
