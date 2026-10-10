import FamilyControls
import Foundation
import Observation

/// Turns shields on for a drive and off when it ends. Settings persist in the App Group.
@MainActor @Observable
final class ShieldingService {
    private(set) var isShielded: Bool
    /// "I'm a passenger" was tapped: shields stay off until this drive ends.
    private(set) var passengerOverride = false
    private(set) var isAuthorized: Bool
    private(set) var status = ""

    var strictMode: Bool { didSet { save(); reapplyIfShielded() } }
    var blocked: FamilyActivitySelection { didSet { save(); reapplyIfShielded() } }
    var allowed: FamilyActivitySelection { didSet { save(); reapplyIfShielded() } }
    var hasCompletedSetup: Bool { didSet { save() } }

    var plan: ShieldPlan { .make(strict: strictMode, blocked: blocked, allowed: allowed) }

    /// Safety window length; the app renews it while shielded, so it only fires if the app dies.
    static let safetyWindow: TimeInterval = 3600
    static let renewInterval: TimeInterval = 900

    private let store: ShieldStore
    private let defaults: UserDefaults
    private var renewTimer: Timer?

    init(store: ShieldStore? = nil,
         defaults: UserDefaults = UserDefaults(suiteName: AppGroup.id) ?? .standard) {
        self.store = store ?? ManagedShieldStore()
        self.defaults = defaults
        strictMode = defaults.bool(forKey: Keys.strict)
        blocked = Self.load(Keys.blocked, from: defaults)
        allowed = Self.load(Keys.allowed, from: defaults)
        hasCompletedSetup = defaults.bool(forKey: Keys.setupDone)
        isShielded = self.store.isActive
        isAuthorized = self.store.isAuthorized
    }

    // MARK: Drive events
    func driveStarted() {
        passengerOverride = false
        shieldOn()
    }

    func driveEnded() {
        passengerOverride = false
        shieldOff("drive ended")
    }

    func imAPassenger() {
        guard isShielded else { return }
        passengerOverride = true
        shieldOff("passenger: shields off for this drive")
    }

    // MARK: Debug / manual
    func shieldNow() { shieldOn() }
    func unshield() { shieldOff("manual unshield") }

    /// Re-read state that may have changed while the app was away (e.g. the safety monitor cleared shields).
    func refresh() {
        isAuthorized = self.store.isAuthorized
        isShielded = self.store.isActive
        if !isShielded { stopRenewing() }
    }

    func requestAuthorization() async {
        do { try await store.requestAuthorization() }
        catch { status = "Screen Time access failed: \(error.localizedDescription)" }
        isAuthorized = self.store.isAuthorized
    }

    // MARK: Private
    private func shieldOn() {
        let plan = plan
        guard plan != .none else {
            status = "nothing to shield: choose apps in Shield settings"
            return
        }
        if !store.isAuthorized { status = "warning: Screen Time access not granted" }
        store.apply(plan)
        isShielded = true
        renewSafety()
        startRenewing()
        if store.isAuthorized { status = strictMode ? "shielded (strict)" : "shielded" }
    }

    private func shieldOff(_ reason: String) {
        store.clear()
        store.cancelSafetyClear()
        stopRenewing()
        isShielded = false
        status = reason
    }

    private func reapplyIfShielded() {
        guard isShielded else { return }
        let plan = plan
        if plan == .none { shieldOff("nothing to shield") } else { store.apply(plan) }
    }

    private func renewSafety() {
        do { try store.armSafetyClear(after: Self.safetyWindow) }
        catch { status = "safety timer failed: \(error.localizedDescription)" }
    }

    private func startRenewing() {
        renewTimer?.invalidate()
        renewTimer = Timer.scheduledTimer(withTimeInterval: Self.renewInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isShielded else { return }
                self.renewSafety()
            }
        }
    }

    private func stopRenewing() {
        renewTimer?.invalidate()
        renewTimer = nil
    }

    private enum Keys {
        static let strict = "shield.strict"
        static let blocked = "shield.blocked"
        static let allowed = "shield.allowed"
        static let setupDone = "shield.setupDone"
    }

    private func save() {
        defaults.set(strictMode, forKey: Keys.strict)
        defaults.set(hasCompletedSetup, forKey: Keys.setupDone)
        defaults.set(try? JSONEncoder().encode(blocked), forKey: Keys.blocked)
        defaults.set(try? JSONEncoder().encode(allowed), forKey: Keys.allowed)
    }

    private static func load(_ key: String, from d: UserDefaults) -> FamilyActivitySelection {
        guard let data = d.data(forKey: key),
              let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return .init() }
        return s
    }
}
