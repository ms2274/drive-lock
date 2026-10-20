import Foundation
import CoreLocation
import CoreMotion
import Observation
import UIKit

struct DebugLogEntry: Identifiable {
    let id = UUID()
    /// Already timestamped (see EventLogFile.line).
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
    /// Any wake-up, so other work (settling pickups) can piggyback on the few seconds iOS gives.
    var onWake: (() -> Void)?

    private var detector: DriveDetector
    private let motion = MotionSource()
    private let location = LocationSource()
    private let gravity = GravitySource()
    @ObservationIgnored private let fence: ParkedFence
    private var awakeTask: UIBackgroundTaskIdentifier = .invalid
    private var pickupDetector = PickupDetector()
    private var lastFix: CLLocation?
    private var lastActivity = Date.distantPast
    /// Last time any sensor input or timer reached us; a long gap means iOS had the app asleep.
    private var lastInput = Date()
    private var timer: Timer?
    private let idleShutdownSeconds: TimeInterval = 180
    private let logFile: EventLogFile
    private let defaults: UserDefaults
    private static let activeDriveKey = "detection.activeDrive"

    /// What gets saved while driving: the detector's drive plus pickups so far.
    struct SavedDrive: Codable, Equatable {
        var drive: DriveDetector.ActiveDrive
        var pickupTimes: [Date]
    }

    var logFileURL: URL { logFile.url }

    init(config: DetectionConfig = .default, logFile: EventLogFile = .default,
         defaults: UserDefaults = .standard) {
        detector = DriveDetector(config: config)
        self.logFile = logFile
        self.defaults = defaults
        fence = ParkedFence(location: location)
        log = logFile.lines(last: 200).reversed().map { DebugLogEntry(text: $0) }
        motion.onAutomotive = { [weak self] auto, start in
            Task { @MainActor in self?.noteInput(); self?.handleAutomotive(auto, since: start) }
        }
        location.onLocations = { [weak self] locs in Task { @MainActor in self?.noteInput(); self?.handleLocations(locs) } }
        location.onSignificantWake = { [weak self] fix in Task { @MainActor in self?.handleSignificantWake(fix) } }
        location.onEvent = { [weak self] text in Task { @MainActor in self?.addLog(text) } }
        motion.onEvent = { [weak self] text in Task { @MainActor in self?.addLog(text) } }
        location.onFenceExit = { [weak self] in Task { @MainActor in self?.handleFenceExit() } }
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
        fence.removeOldMonitor()
        motion.start()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        resumeSavedDrive()
        addLog("detection started (location auth \(location.authorization.rawValue), background updates \(location.backgroundUpdatesAllowed), motion auth \(MotionSource.authorization.rawValue))")
        handleWake(reason: "start")
    }

    func stop() {
        timer?.invalidate(); motion.stop(); gravity.stop(); setMode(.off)
        addLog("stopped")
    }

    /// Diagnostic line from outside detection (app launch, scene changes, shields).
    func note(_ text: String) { addLog(text) }

    func clearLog() { logFile.clear(); log = [] }

    // MARK: Inputs
    private func handleSignificantWake(_ fix: CLLocation?) {
        if let f = fix {
            addLog(String(format: "significant-change wake: fix %.0f s old, %.0f mph, ±%.0f m",
                          Date().timeIntervalSince(f.timestamp), max(f.speed, 0) * 2.23694, f.horizontalAccuracy))
        } else {
            addLog("significant-change wake: no fix")
        }
        if let f = fix, f.horizontalAccuracy >= 0, f.horizontalAccuracy <= 100, state == .idle { fence.place(at: f) }
        handleWake(reason: "significant change", fix: fix)
    }

    /// iOS often wakes the app for a few seconds with no significant-change event. Catch up on
    /// motion history then too, so a drive that began minutes ago can start on this wake.
    private func noteInput() {
        let asleep = Date().timeIntervalSince(lastInput)
        lastInput = Date()
        if asleep > 45 && !isDriving {
            handleWake(reason: String(format: "woke after %.0f s asleep", asleep))
        }
    }

    private var isDriving: Bool { if case .driving = state { return true } else { return false } }

    /// Left the ring around where we were parked: likely pulling away. Get a fix (to judge speed
    /// and to drop the next ring) and catch up on motion history.
    private func handleFenceExit() {
        lastActivity = Date()
        if trackingMode == .off { setMode(.low) }
        handleWake(reason: "left parked fence")
    }

    /// iOS gives a woken app only a few seconds. Ask for up to ~25 s so a GPS fix can arrive.
    private func holdAwake() {
        guard awakeTask == .invalid else { return }
        awakeTask = UIApplication.shared.beginBackgroundTask(withName: "drive-check") { [weak self] in
            self?.releaseAwake()
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(25))
            self?.releaseAwake()
        }
    }

    private func releaseAwake() {
        guard awakeTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(awakeTask)
        awakeTask = .invalid
    }

    private func handleWake(reason: String, fix: CLLocation? = nil) {
        lastActivity = Date()
        lastInput = Date()
        holdAwake()
        onWake?()
        motion.recentAutomotive(since: Date().addingTimeInterval(-600)) { [weak self] since, history in
            Task { @MainActor in
                guard let self else { return }
                let sinceText = since.map { $0.formatted(date: .omitted, time: .standard) } ?? "no"
                self.addLog("wake (\(reason)): automotive since \(sinceText); last 5 min: \(history)")
                if let since { self.handleAutomotive(true, since: since) }
                // The fix that woke us is real evidence (often already at speed). Use it now:
                // iOS may suspend the app again before GPS delivers another one.
                // Same for a fix that arrived moments ago, before the history answered.
                if let fix = fix ?? self.lastFix, Date().timeIntervalSince(fix.timestamp) < 60 {
                    self.handleLocations([fix])
                }
            }
        }
    }

    private func handleAutomotive(_ auto: Bool, since: Date? = nil) {
        automotive = auto
        if auto { lastActivity = Date() }
        feed(DetectorSample(time: now(), isAutomotive: auto,
                            automotiveSince: since?.timeIntervalSinceReferenceDate))
        applyMode()
    }

    private func handleLocations(_ locs: [CLLocation]) {
        for loc in locs {
            guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= detector.config.maxHorizontalAccuracy else { continue }
            // Mid-drive, iOS lets the app sleep for minutes between fixes; the straight line across
            // that gap is real driving (a little short on curvy roads). Outside a drive, a gap means
            // the app woke somewhere new, so count nothing.
            let maxGap: TimeInterval = state == .idle ? 60 : 900
            let delta = lastFix.map {
                Self.fixDelta(meters: loc.distance(from: $0),
                              seconds: loc.timestamp.timeIntervalSince($0.timestamp), maxGap: maxGap)
            } ?? 0
            let displacement = lastFix.map { loc.distance(from: $0) }
            lastFix = loc
            if state == .idle { fence.place(at: loc) }
            let speed = loc.speed >= 0 ? loc.speed : nil
            if let s = speed { speedMph = s * 2.23694 }
            feed(DetectorSample(time: loc.timestamp.timeIntervalSinceReferenceDate,
                                speed: speed, distanceDelta: delta, displacement: displacement))
        }
    }

    private func handleGravity(_ sample: GravitySample, at date: Date) {
        guard pickupDetector.ingest(sample) else { return }
        pickupTimes.append(date)
        pickupCount = pickupDetector.count
        addLog("pickup #\(pickupCount)")
        saveActiveDrive()
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
        noteInput()
        feed(DetectorSample(time: now()))
        saveActiveDrive()
        // Heartbeat while GPS is on: gaps in these lines mean iOS suspended the app.
        if trackingMode != .off {
            addLog(String(format: "tick: %@, automotive %@, %.0f mph, GPS %@",
                          String(describing: state), automotive ? "yes" : "no", speedMph, trackingMode.rawValue))
        }
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
            saveActiveDrive()
            onDriveStarted?(Date(timeIntervalSinceReferenceDate: t))
        case .driveEnded(let s, let e, let m):
            gravity.stop()
            if let f = lastFix { fence.place(at: f) }
            defaults.removeObject(forKey: Self.activeDriveKey)
            addLog(String(format: "DRIVE ENDED %.2f mi", m / 1609.344))
            onDriveEnded?(Date(timeIntervalSinceReferenceDate: s), Date(timeIntervalSinceReferenceDate: e), m)
        }
    }

    // MARK: Drive in progress survives relaunch
    private func saveActiveDrive() {
        guard let drive = detector.activeDrive else { return }
        let saved = SavedDrive(drive: drive, pickupTimes: pickupTimes)
        defaults.set(try? JSONEncoder().encode(saved), forKey: Self.activeDriveKey)
    }

    /// If iOS killed the app mid-drive, carry on with that drive instead of losing it.
    private func resumeSavedDrive() {
        guard detector.activeDrive == nil,
              let data = defaults.data(forKey: Self.activeDriveKey),
              let saved = try? JSONDecoder().decode(SavedDrive.self, from: data) else { return }
        detector.resume(saved.drive)
        state = detector.state
        miles = detector.meters / 1609.344
        pickupTimes = saved.pickupTimes
        pickupCount = saved.pickupTimes.count
        lastActivity = Date()
        gravity.start()
        applyMode()
        addLog(String(format: "RESUMED drive started %@, %.2f mi, %d pickups so far",
                      Date(timeIntervalSinceReferenceDate: saved.drive.since).formatted(date: .omitted, time: .standard),
                      miles, pickupCount))
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
        let line = EventLogFile.line(text)
        logFile.append(line)
        log.insert(DebugLogEntry(text: line), at: 0)
        if log.count > 200 { log.removeLast() }
    }
}
