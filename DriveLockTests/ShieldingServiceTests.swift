import FamilyControls
import XCTest
@testable import DriveLock

@MainActor
final class FakeShieldStore: ShieldStore {
    var isAuthorized = true
    var isActive = false
    var applied: [ShieldPlan] = []
    var clears = 0
    var armedSeconds: TimeInterval?

    func requestAuthorization() async throws {}
    func apply(_ plan: ShieldPlan) { applied.append(plan); isActive = true }
    func clear() { clears += 1; isActive = false }
    func armSafetyClear(after seconds: TimeInterval) throws { armedSeconds = seconds }
    func cancelSafetyClear() { armedSeconds = nil }
}

@MainActor
final class ShieldingServiceTests: XCTestCase {
    private var store: FakeShieldStore!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        store = FakeShieldStore()
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    private func makeService(strict: Bool = true) -> ShieldingService {
        let s = ShieldingService(store: store, defaults: defaults)
        // Selections are opaque tokens we can't build in tests, so strict mode
        // (which shields even with an empty allow-list) drives most cases.
        s.strictMode = strict
        return s
    }

    func testEmptyBlockListMeansNothingToShield() {
        XCTAssertEqual(ShieldPlan.make(strict: false, blocked: .init(), allowed: .init()), .none)
    }

    func testStrictModeShieldsEvenWithNothingAllowed() {
        XCTAssertEqual(ShieldPlan.make(strict: true, blocked: .init(), allowed: .init()), .allowOnly(.init()))
    }

    func testDriveStartShieldsAndArmsSafetyThenEndClears() {
        let s = makeService()
        s.driveStarted()
        XCTAssertTrue(s.isShielded)
        XCTAssertEqual(store.applied, [.allowOnly(.init())])
        XCTAssertEqual(store.armedSeconds, ShieldingService.safetyWindow)

        s.driveEnded()
        XCTAssertFalse(s.isShielded)
        XCTAssertFalse(store.isActive)
        XCTAssertNil(store.armedSeconds, "safety window cancelled on normal end")
    }

    func testBlockModeWithNothingChosenDoesNotShield() {
        let s = makeService(strict: false)
        s.driveStarted()
        XCTAssertFalse(s.isShielded)
        XCTAssertTrue(store.applied.isEmpty)
        XCTAssertTrue(s.status.contains("choose apps"))
    }

    func testPassengerLiftsShieldsOnlyForThisDrive() {
        let s = makeService()
        s.driveStarted()
        s.imAPassenger()
        XCTAssertFalse(s.isShielded)
        XCTAssertTrue(s.passengerOverride)

        s.driveEnded()
        XCTAssertFalse(s.passengerOverride)
        s.driveStarted()
        XCTAssertTrue(s.isShielded, "next drive shields again")
    }

    func testPassengerDoesNothingWhenNotShielded() {
        let s = makeService()
        s.imAPassenger()
        XCTAssertFalse(s.passengerOverride)
    }

    func testTurningStrictOffWithEmptyBlockListMidDriveUnshields() {
        let s = makeService()
        s.driveStarted()
        s.strictMode = false
        XCTAssertFalse(s.isShielded)
    }

    func testRelaunchPicksUpExistingShields() {
        store.isActive = true
        XCTAssertTrue(ShieldingService(store: store, defaults: defaults).isShielded)
    }

    func testRefreshNoticesShieldsClearedBySafetyMonitor() {
        let s = makeService()
        s.driveStarted()
        store.isActive = false   // monitor extension cleared the store
        s.refresh()
        XCTAssertFalse(s.isShielded)
    }

    func testPassengerChoiceSurvivesRelaunchUntilDriveEnds() {
        let s = makeService()
        s.driveStarted()
        s.imAPassenger()
        let relaunched = ShieldingService(store: store, defaults: defaults)
        XCTAssertTrue(relaunched.passengerOverride)
        relaunched.driveEnded()
        XCTAssertFalse(ShieldingService(store: store, defaults: defaults).passengerOverride)
    }

    func testSettingsPersist() {
        let s = makeService()
        s.hasCompletedSetup = true
        let reloaded = ShieldingService(store: store, defaults: defaults)
        XCTAssertTrue(reloaded.strictMode)
        XCTAssertTrue(reloaded.hasCompletedSetup)
    }
}
