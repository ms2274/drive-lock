import Foundation

/// One observation fed to the detector. `nil` means "no new information".
struct DetectorSample: Equatable {
    var time: TimeInterval            // seconds, any monotonic origin
    var speed: Double? = nil          // m/s; nil if unknown/invalid
    var isAutomotive: Bool? = nil     // nil keeps the previous value
    /// When iOS says the automotive activity began (it often knows before the app wakes up).
    var automotiveSince: TimeInterval? = nil
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
    /// Start of the current unbroken automotive stretch.
    private var automotiveSince: TimeInterval?
    private var lastSampleTime: TimeInterval?
    /// When the app's current stretch of being awake began. A stop only counts once we've
    /// actually watched it: time asleep is not time stopped.
    private var awakeSince: TimeInterval = 0
    private var lastGood: TimeInterval = 0     // last time start conditions held
    private var lastMoving: TimeInterval = 0   // last time speed >= movingSpeed
    private var pendingMeters: Double = 0

    init(config: DetectionConfig = .default) { self.config = config }

    mutating func ingest(_ s: DetectorSample) -> [DetectorEvent] {
        if let a = s.isAutomotive {
            automotive = a
            if !a { automotiveSince = nil }
            else if let since = s.automotiveSince { automotiveSince = min(automotiveSince ?? since, since) }
            else if automotiveSince == nil { automotiveSince = s.time }
        }
        // First tick after the app slept: no evidence either way, so wait for a fresh fix.
        let gap = lastSampleTime.map { s.time - $0 } ?? .infinity
        if gap > config.staleGapSeconds { awakeSince = s.time }
        lastSampleTime = max(lastSampleTime ?? s.time, s.time)
        if s.speed == nil && gap > config.staleGapSeconds && gap.isFinite { return [] }

        let speed = s.speed ?? 0
        let good = automotive && speed >= config.startSpeed
        var events: [DetectorEvent] = []

        // iOS has seen "automotive" for long enough and we're moving fast: start now, back-dated,
        // instead of needing 30 s of our own observation (the app may only be awake for seconds).
        if good, let a = automotiveSince, s.time - a >= config.startConfirmSeconds {
            switch state {
            case .idle, .suspected:
                var since = max(a, s.time - config.maxBackdateSeconds)
                if case .suspected(let s0) = state { since = min(since, s0) }
                meters = pendingMeters + s.distanceDelta
                pendingMeters = 0
                lastMoving = s.time
                state = .driving(since: since)
                return [.stateChanged(state), .driveStarted(at: since)]
            case .driving:
                break
            }
        }

        switch state {
        case .idle:
            if good {
                lastGood = s.time
                pendingMeters = s.distanceDelta
                state = .suspected(since: s.time)
                events.append(.stateChanged(state))
            }

        case .suspected(let since):
            pendingMeters += s.distanceDelta
            if good { lastGood = s.time }
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
            // Ends after a stop we watched for the full minute, or once iOS says we're out of
            // the car (walking, stationary) and nothing has moved for a minute.
            let watchedStop = s.time - max(lastMoving, awakeSince)
            let stopped = s.time - lastMoving
            if watchedStop >= config.stopEndSeconds || (!automotive && stopped >= config.stopEndSeconds) {
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
        // Treat the relaunch like waking from sleep: the first tick isn't evidence of a stop.
        lastSampleTime = d.lastMoving
    }

    /// Re-evaluate timers without new sensor data.
    mutating func tick(at time: TimeInterval) -> [DetectorEvent] {
        ingest(DetectorSample(time: time))
    }
}
