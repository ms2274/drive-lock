import XCTest
@testable import DriveLock

final class DriveSummaryTests: XCTestCase {
    func testCleanDriveShowsScoreAndStreak() {
        let s = DriveSummary.make(miles: 3.24, pickups: 0, result: .init(score: 100, outcome: .clean), streak: 6)
        XCTAssertEqual(s, DriveSummary(title: "Clean drive: 100", body: "3.2 mi, no pickups. Streak: 6."))
    }

    func testNotCleanDriveSaysStreakReset() {
        let s = DriveSummary.make(miles: 5, pickups: 3, result: .init(score: 70, outcome: .notClean), streak: 0)
        XCTAssertEqual(s?.title, "Drive scored 70")
        XCTAssertTrue(s?.body.hasPrefix("5.0 mi, 3 pickups.") ?? false)
    }

    func testPassengerRide() {
        let s = DriveSummary.make(miles: 2, pickups: 4, result: .init(score: nil, outcome: .passenger), streak: 0)
        XCTAssertEqual(s?.title, "Passenger ride")
    }

    func testShortDrivesGetNoNotification() {
        XCTAssertNil(DriveSummary.make(miles: 0.3, pickups: 0, result: .init(score: nil, outcome: .unscored), streak: 2))
    }
}
