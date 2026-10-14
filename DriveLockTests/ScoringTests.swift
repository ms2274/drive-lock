import SwiftData
import XCTest
@testable import DriveLock

final class ScoringTests: XCTestCase {
    func testNoPickupsScoresFull() {
        let r = TripScorer.result(miles: 5, pickups: 0, passenger: false)
        XCTAssertEqual(r, TripResult(score: 100, outcome: .clean))
    }

    func testTwoPickupsStillClean() {
        let r = TripScorer.result(miles: 5, pickups: 2, passenger: false)
        XCTAssertEqual(r, TripResult(score: 80, outcome: .clean))
    }

    func testThreePickupsNotClean() {
        let r = TripScorer.result(miles: 5, pickups: 3, passenger: false)
        XCTAssertEqual(r, TripResult(score: 70, outcome: .notClean))
    }

    func testScoreFloorsAtZero() {
        XCTAssertEqual(TripScorer.result(miles: 5, pickups: 50, passenger: false).score, 0)
    }

    func testShortDriveUnscored() {
        let r = TripScorer.result(miles: 0.2, pickups: 5, passenger: false)
        XCTAssertEqual(r, TripResult(score: nil, outcome: .unscored))
    }

    func testPassengerOverrideUnscored() {
        let r = TripScorer.result(miles: 5, pickups: 0, passenger: true)
        XCTAssertEqual(r, TripResult(score: nil, outcome: .passenger))
    }

    func testStreakCountsCleanBackToBreak() {
        XCTAssertEqual(Streak.current(newestFirst: [.clean, .clean, .notClean, .clean]), 2)
    }

    func testPassengerResetsStreak() {
        XCTAssertEqual(Streak.current(newestFirst: [.passenger, .clean, .clean]), 0)
        XCTAssertEqual(Streak.current(newestFirst: [.clean, .passenger, .clean]), 1)
    }

    func testShortDrivesDoNotBreakStreak() {
        XCTAssertEqual(Streak.current(newestFirst: [.clean, .unscored, .clean]), 2)
    }

    func testEmptyStreakIsZero() {
        XCTAssertEqual(Streak.current(newestFirst: []), 0)
    }
}

final class ShieldAttemptLogTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
    }

    func testCountsOnlyAttemptsInsideTheDrive() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        ShieldAttemptLog.record(at: t0.addingTimeInterval(-60), directory: dir)
        ShieldAttemptLog.record(at: t0.addingTimeInterval(10), directory: dir)
        ShieldAttemptLog.record(at: t0.addingTimeInterval(100), directory: dir)
        ShieldAttemptLog.record(at: t0.addingTimeInterval(500), directory: dir)
        let n = ShieldAttemptLog.count(from: t0, to: t0.addingTimeInterval(200), directory: dir)
        XCTAssertEqual(n, 2)
    }

    func testRepeatsWithinWindowMergeIntoOne() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        ShieldAttemptLog.record(at: t0, directory: dir)
        ShieldAttemptLog.record(at: t0.addingTimeInterval(1), directory: dir)
        ShieldAttemptLog.record(at: t0.addingTimeInterval(2), directory: dir)
        XCTAssertEqual(ShieldAttemptLog.count(from: t0, to: t0.addingTimeInterval(10), directory: dir), 1)
    }
}

@MainActor
final class TripRecorderTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: Trip.self, configurations: config))
    }

    func testRecordsScoredTrip() throws {
        let ctx = try makeContext()
        var recorder = TripRecorder(context: ctx)
        recorder.pickupCount = { _, _ in 1 }
        let t = recorder.record(start: .now, end: .now.addingTimeInterval(600),
                                meters: 8_046.72, passenger: false)
        XCTAssertEqual(t.miles, 5, accuracy: 0.001)
        XCTAssertEqual(t.pickups, 1)
        XCTAssertEqual(t.score, 90)
        XCTAssertEqual(t.outcome, .clean)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Trip>()).count, 1)
    }

    func testPassengerTripIsFlagged() throws {
        let recorder = TripRecorder(context: try makeContext(), pickupCount: { _, _ in 0 })
        let t = recorder.record(start: .now, end: .now.addingTimeInterval(600),
                                meters: 8_046.72, passenger: true)
        XCTAssertEqual(t.outcome, .passenger)
        XCTAssertNil(t.score)
    }
}
