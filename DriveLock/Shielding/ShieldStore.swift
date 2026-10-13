import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Everything ShieldingService needs from Screen Time; faked in tests.
@MainActor
protocol ShieldStore: AnyObject {
    var isAuthorized: Bool { get }
    /// True if shields are currently written (they survive app relaunch).
    var isActive: Bool { get }
    /// What the system store currently holds, for the debug screen.
    var appliedSummary: String { get }
    func requestAuthorization() async throws
    func apply(_ plan: ShieldPlan)
    func clear()
    /// (Re)start the safety window; the monitor extension clears shields when it ends.
    func armSafetyClear(after seconds: TimeInterval) throws
    func cancelSafetyClear()
}

extension ShieldStore {
    var appliedSummary: String { "n/a" }
}

@MainActor
final class ManagedShieldStore: ShieldStore {
    private let store = ManagedSettingsStore(named: .driving)
    private let center = DeviceActivityCenter()

    var isAuthorized: Bool { AuthorizationCenter.shared.authorizationStatus == .approved }
    var isActive: Bool { store.shield.applicationCategories != nil || store.shield.applications != nil }

    var appliedSummary: String {
        let apps = store.shield.applications?.count ?? 0
        let cats = store.shield.applicationCategories == nil ? "no" : "yes"
        let webs = store.shield.webDomains?.count ?? 0
        return "apps \(apps), categories \(cats), sites \(webs)"
    }

    func requestAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    func apply(_ plan: ShieldPlan) {
        store.clearAllSettings()
        switch plan {
        case .none:
            break
        case .block(let s):
            store.shield.applications = s.applicationTokens.isEmpty ? nil : s.applicationTokens
            store.shield.applicationCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
            store.shield.webDomains = s.webDomainTokens.isEmpty ? nil : s.webDomainTokens
            store.shield.webDomainCategories = s.categoryTokens.isEmpty ? nil : .specific(s.categoryTokens)
        case .allowOnly(let s):
            store.shield.applicationCategories = .all(except: s.applicationTokens)
            store.shield.webDomainCategories = .all(except: s.webDomainTokens)
        }
    }

    func clear() { store.clearAllSettings() }

    func armSafetyClear(after seconds: TimeInterval) throws {
        let cal = Calendar.current
        let parts: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let now = Date()
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents(parts, from: now),
            intervalEnd: cal.dateComponents(parts, from: now.addingTimeInterval(seconds)),
            repeats: false)
        center.stopMonitoring([.driveSafety])
        try center.startMonitoring(.driveSafety, during: schedule)
    }

    func cancelSafetyClear() { center.stopMonitoring([.driveSafety]) }
}
