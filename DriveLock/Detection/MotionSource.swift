import CoreMotion

/// Thin wrapper over CMMotionActivityManager. Emits only automotive true/false.
final class MotionSource {
    private let manager = CMMotionActivityManager()
    var onAutomotive: ((Bool, Date) -> Void)?
    /// Diagnostic lines for the event log.
    var onEvent: ((String) -> Void)?
    private var lastLogged = ""

    static var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }
    static var authorization: CMAuthorizationStatus { CMMotionActivityManager.authorizationStatus() }

    func start() {
        guard Self.isAvailable else { return }
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let a = activity else { return }
            let desc = Self.describe(a)
            if desc != self.lastLogged { self.lastLogged = desc; self.onEvent?("motion: \(desc)") }
            guard a.confidence != .low else { return }
            self.onAutomotive?(a.automotive, a.startDate)
        }
    }

    func stop() { manager.stopActivityUpdates() }

    /// Called on background wake-ups to catch up on what happened while suspended.
    /// `automotiveSince` is when the current unbroken automotive stretch began (nil if not automotive now).
    /// `history` lists every activity change in the window, for the event log.
    func recentAutomotive(since: Date, completion: @escaping (_ automotiveSince: Date?, _ history: String) -> Void) {
        guard Self.isAvailable else { return completion(nil, "motion unavailable") }
        manager.queryActivityStarting(from: since, to: Date(), to: .main) { acts, error in
            let acts = acts ?? []
            let history = acts.isEmpty ? (error.map { "error \($0.localizedDescription)" } ?? "none")
                : acts.suffix(8).map { "\(Self.time($0.startDate)) \(Self.describe($0))" }.joined(separator: ", ")
            completion(Self.automotiveSince(acts), history)
        }
    }

    /// Walk back from the newest confident activity while it's automotive. Low-confidence
    /// blips (e.g. "automotive+stationary (low)" at lights) don't break the stretch.
    static func automotiveSince(_ acts: [CMMotionActivity]) -> Date? {
        var since: Date?
        for a in acts.reversed() where a.confidence != .low {
            guard a.automotive else { break }
            since = a.startDate
        }
        return since
    }

    static func describe(_ a: CMMotionActivity) -> String {
        var kinds: [String] = []
        if a.automotive { kinds.append("automotive") }
        if a.cycling { kinds.append("cycling") }
        if a.running { kinds.append("running") }
        if a.walking { kinds.append("walking") }
        if a.stationary { kinds.append("stationary") }
        if a.unknown { kinds.append("unknown") }
        let conf = ["low", "med", "high"][a.confidence.rawValue]
        return "\(kinds.isEmpty ? "none" : kinds.joined(separator: "+")) (\(conf))"
    }

    private static func time(_ d: Date) -> String {
        d.formatted(date: .omitted, time: .standard)
    }
}
