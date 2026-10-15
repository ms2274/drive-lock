import Foundation

/// One observation fed to the detector. `nil` means "no new information".
struct DetectorSample: Equatable {
    var time: TimeInterval            // seconds, any monotonic origin
    var speed: Double? = nil          // m/s; nil if unknown/invalid
    var isAutomotive: Bool? = nil     // nil keeps the previous value
    var distanceDelta: Double = 0     // meters since previous fix
}

enum DriveState: Equatable {
    case idle
    case suspected(since: TimeInterval)
    case driving(since: TimeInterval)
}

enum DetectorEvent: Equatable {
    case stateChanged(DriveState)
    case driveStarted(at: TimeInterval)
    case driveEnded(start: TimeInterval, end: TimeInterval, meters: Double)
}

/// Pure state machine: no clocks, no CoreMotion, no CoreLocation.
/// Feed samples (or empty "tick" samples) and read back events.
struct DriveDetector {
    private(set) var state: DriveState = .idle
    private(set) var meters: Double = 0
    let config: DetectionConfig

    private var automotive = false
    private var lastGood: TimeInterval = 0     // last time start conditions held
    private var lastMoving: TimeInterval = 0   // last time speed >= movingSpeed
    private var pendingMeters: Double = 0

    init(config: DetectionConfig = .default) { self.config = config }

    mutating func ingest(_ s: DetectorSample) -> [DetectorEvent] {
        if let a = s.isAutomotive { automotive = a }
        let speed = s.speed ?? 0
        var events: [DetectorEvent] = []

        switch state {
        case .idle:
            if automotive && speed >= config.startSpeed {
                lastGood = s.time
                pendingMeters = s.distanceDelta
                state = .suspected(since: s.time)
                events.append(.stateChanged(state))
            }

        case .suspected(let since):
            pendingMeters += s.distanceDelta
            if automotive && speed >= config.startSpeed { lastGood = s.time }
            if s.time - lastGood > config.suspectGraceSeconds {
                pendingMeters = 0
                state = .idle
                events.append(.stateChanged(state))
            } else if s.time - since >= config.startConfirmSeconds {
                meters = pendingMeters
                lastMoving = s.time
                state = .driving(since: since)
                events.append(.stateChanged(state))
                events.append(.driveStarted(at: since))
            }

        case .driving(let since):
            meters += s.distanceDelta
            if speed >= config.movingSpeed { lastMoving = s.time }
            let stopped = s.time - lastMoving
            if stopped >= config.stopEndSeconds && (!automotive || stopped >= config.hardStopSeconds) {
                // Trip ends when movement stopped, not when the debounce expired.
                let end = lastMoving
                let total = meters
                meters = 0
                state = .idle
                events.append(.driveEnded(start: since, end: end, meters: total))
                events.append(.stateChanged(state))
            }
        }
        return events
    }

    /// A drive in progress, saved so it survives the app being killed and relaunched mid-drive.
    struct ActiveDrive: Codable, Equatable {
        var since: TimeInterval
        var lastMoving: TimeInterval
        var meters: Double
    }

    var activeDrive: ActiveDrive? {
        guard case .driving(let since) = state else { return nil }
        return ActiveDrive(since: since, lastMoving: lastMoving, meters: meters)
    }

    /// Pick a saved drive back up. The next sample ends it normally if movement stopped long ago.
    mutating func resume(_ d: ActiveDrive) {
        state = .driving(since: d.since)
        lastMoving = d.lastMoving
        meters = d.meters
    }

    /// Re-evaluate timers without new sensor data.
    mutating func tick(at time: TimeInterval) -> [DetectorEvent] {
        ingest(DetectorSample(time: time))
    }
}
