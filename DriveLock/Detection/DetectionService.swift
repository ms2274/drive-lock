import Foundation
import CoreLocation
import CoreMotion
import Observation

struct DebugLogEntry: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
}

/// Wires live sensors to the pure DriveDetector and manages battery modes.
@MainActor @Observable
final class DetectionService {
    private(set) var state: DriveState = .idle
    private(set) var automotive = false
    private(set) var speedMph: Double = 0
    private(set) var miles: Double = 0
    private(set) var trackingMode: TrackingMode = .off
    private(set) var log: [DebugLogEntry] = []
    private(set) var locationAuthorization: CLAuthorizationStatus = .notDetermined
    private(set) var motionAuthorization: CMAuthorizationStatus = .notDetermined
    /// Pickups seen during the current (or last) drive, live for the debug screen.
    private(set) var pickupCount = 0
    private var pickupTimes: [Date] = []

    /// Fired for consumers (shielding in milestone b, trip recording in c).
    var onDriveStarted: ((Date) -> Void)?
    var onDriveEnded: ((_ start: Date, _ end: Date, _ meters: Double) -> Void)?

    private var detector: DriveDetector
    private let motion = MotionSource()
    private let location = LocationSource()
    private let gravity = GravitySource()
    private var pickupDetector = PickupDetector()
    private var lastFix: CLLocation?
    private var lastActivity = Date.distantPast
    private var timer: Timer?
    private let idleShutdownSeconds: TimeInterval = 180

    init(config: DetectionConfig = .default) {
        detector = DriveDetector(config: config)
        motion.onAutomotive = { [weak self] auto, _ in Task { @MainActor in self?.handleAutomotive(auto) } }
        location.onLocations = { [weak self] locs in Task { @MainActor in self?.handleLocations(locs) } }
        location.onSignificantWake = { [weak self] in Task { @MainActor in self?.handleWake() } }
        location.onAuthChange = { [weak self] in Task { @MainActor in self?.refreshPermissions() } }
        gravity.onSample = { [weak self] sample, date in
            Task { @MainActor in self?.handleGravity(sample, at: date) }
        }
    }

    func requestPermissions() { location.requestAlways() }

    /// Re-read permission state; the Home screen shows what is missing.
    func refreshPermissions() {
        locationAuthorization = location.authorization
        motionAuthorization = MotionSource.authorization
    }

    func start() {
        refreshPermissions()
        location.startMonitoring()
        motion.start()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        addLog("started (auth: \(location.authorization.rawValue), motion: \(MotionSource.authorization.rawValue))")
        handleWake()
    }

    func stop() {
        timer?.invalidate(); motion.stop(); gravity.stop(); setMode(.off)
        addLog("stopped")
    }

    // MARK: Inputs
    private func handleWake() {
        lastActivity = Date()
        motion.recentAutomotive(since: Date().addingTimeInterval(-300)) { [weak self] auto in
            Task { @MainActor in
                guard let self else { return }
                self.addLog("wake: recent automotive=\(auto)")
                if auto { self.handleAutomotive(true) }
            }
        }
    }

    private func handleAutomotive(_ auto: Bool) {
        automotive = auto
        if auto { lastActivity = Date() }
        feed(DetectorSample(time: now(), isAutomotive: auto))
        applyMode()
    }

    private func handleLocations(_ locs: [CLLocation]) {
        for loc in locs {
            guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= detector.config.maxHorizontalAccuracy else { continue }
            let delta = lastFix.map {
                Self.fixDelta(meters: loc.distance(from: $0),
                              seconds: loc.timestamp.timeIntervalSince($0.timestamp))
            } ?? 0
            lastFix = loc
            let speed = loc.speed >= 0 ? loc.speed : nil
            if let s = speed { speedMph = s * 2.23694 }
            feed(DetectorSample(time: loc.timestamp.timeIntervalSinceReferenceDate,
                                speed: speed, distanceDelta: delta))
        }
    }

    private func handleGravity(_ sample: GravitySample, at date: Date) {
        guard pickupDetector.ingest(sample) else { return }
        pickupTimes.append(date)
        pickupCount = pickupDetector.count
        addLog("pickup #\(pickupCount)")
    }

    /// Debug: count pickups without a drive, so the sensor can be tried at a desk.
    private(set) var isPickupTesting = false

    func startPickupTest() {
        pickupDetector.reset(); pickupTimes = []; pickupCount = 0
        gravity.start()
        isPickupTesting = true
    }

    func stopPickupTest() {
        if state == .idle { gravity.stop() }
        isPickupTesting = false
    }

    /// Pickups inside a drive. Handling after the (back-dated) drive end, while parked, is not counted.
    func pickups(from start: Date, to end: Date) -> Int {
        pickupTimes.filter { $0 >= start && $0 <= end }.count
    }

    /// Distance to count between two fixes. A stale previous fix (app was suspended) or an impossible
    /// speed means the app woke up somewhere new, not that it drove that far, so count nothing.
    nonisolated static func fixDelta(meters: Double, seconds: TimeInterval,
                                     maxGap: TimeInterval = 60, maxSpeed: Double = 70) -> Double {
        guard seconds > 0, seconds <= maxGap, meters / seconds <= maxSpeed else { return 0 }
        return meters
    }

    private func tick() {
        feed(DetectorSample(time: now()))
        // Battery: stop GPS after a quiet spell with no automotive signal.
        if state == .idle, !automotive, Date().timeIntervalSince(lastActivity) > idleShutdownSeconds,
           trackingMode != .off {
            setMode(.off); lastFix = nil
            addLog("idle: GPS off (significant-change only)")
        }
    }

    private func now() -> TimeInterval { Date().timeIntervalSinceReferenceDate }

    private func feed(_ sample: DetectorSample) {
        for e in detector.ingest(sample) { handle(e) }
        miles = detector.meters / 1609.344
    }

    private func handle(_ e: DetectorEvent) {
        switch e {
        case .stateChanged(let s):
            state = s; lastActivity = Date()
            applyMode()
            addLog("state → \(s)")
        case .driveStarted(let t):
            addLog("DRIVE STARTED")
            pickupDetector.reset()
            pickupTimes = []
            pickupCount = 0
            gravity.start()
            onDriveStarted?(Date(timeIntervalSinceReferenceDate: t))
        case .driveEnded(let s, let e, let m):
            gravity.stop()
            addLog(String(format: "DRIVE ENDED %.2f mi", m / 1609.344))
            onDriveEnded?(Date(timeIntervalSinceReferenceDate: s), Date(timeIntervalSinceReferenceDate: e), m)
        }
    }

    private func applyMode() {
        let want: TrackingMode
        switch state {
        case .idle: want = automotive ? .low : trackingMode
        case .suspected, .driving: want = .high
        }
        setMode(want)
    }

    private func setMode(_ m: TrackingMode) { location.setMode(m); trackingMode = m }

    private func addLog(_ text: String) {
        log.insert(DebugLogEntry(text: text), at: 0)
        if log.count > 200 { log.removeLast() }
    }
}
