import Foundation

/// Tunables for spotting "phone picked up". Angles in degrees, durations in seconds.
struct PickupConfig: Equatable {
    /// Gravity direction must swing at least this far within `windowSeconds`.
    var tiltDegrees = 35.0
    var windowSeconds = 2.0
    /// Handling within this long of the last tilt is the same pickup (picking up, then putting down).
    var quietSeconds = 20.0

    static let `default` = PickupConfig()
}

/// Direction of gravity in the phone's own frame. Turns and bumps barely move it; lifting the phone does.
struct GravitySample: Equatable {
    var time: TimeInterval
    var x: Double
    var y: Double
    var z: Double
}

/// Pure state machine like DriveDetector: feed samples in order, read `count`.
struct PickupDetector {
    let config: PickupConfig
    private(set) var count = 0
    private var window: [GravitySample] = []
    private var lastTilt = -Double.infinity

    init(config: PickupConfig = .default) { self.config = config }

    /// Returns true when this sample starts a new pickup.
    @discardableResult
    mutating func ingest(_ s: GravitySample) -> Bool {
        window.append(s)
        window.removeAll { s.time - $0.time > config.windowSeconds }
        guard let ref = window.first, Self.angle(ref, s) >= config.tiltDegrees else { return false }
        let isNew = s.time - lastTilt >= config.quietSeconds
        lastTilt = s.time
        if isNew { count += 1 }
        return isNew
    }

    mutating func reset() {
        count = 0
        window = []
        lastTilt = -.infinity
    }

    static func angle(_ a: GravitySample, _ b: GravitySample) -> Double {
        let na = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
        let nb = (b.x * b.x + b.y * b.y + b.z * b.z).squareRoot()
        guard na > 0.001, nb > 0.001 else { return 0 }
        let c = (a.x * b.x + a.y * b.y + a.z * b.z) / (na * nb)
        return acos(max(-1, min(1, c))) * 180 / .pi
    }
}
