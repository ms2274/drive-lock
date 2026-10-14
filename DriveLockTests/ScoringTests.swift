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

@MainActor
final class TripRecorderTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: Trip.self, configurations: config))
    }

    func testRecordsScoredTrip() throws {
        let ctx = try makeContext()
        let recorder = TripRecorder(context: ctx)
        let t = recorder.record(start: .now, end: .now.addingTimeInterval(600),
                                meters: 8_046.72, pickups: 1, passenger: false)
        XCTAssertEqual(t.miles, 5, accuracy: 0.001)
        XCTAssertEqual(t.pickups, 1)
        XCTAssertEqual(t.score, 90)
        XCTAssertEqual(t.outcome, .clean)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Trip>()).count, 1)
    }

    func testPassengerTripIsFlagged() throws {
        let recorder = TripRecorder(context: try makeContext())
        let t = recorder.record(start: .now, end: .now.addingTimeInterval(600),
                                meters: 8_046.72, pickups: 0, passenger: true)
        XCTAssertEqual(t.outcome, .passenger)
        XCTAssertNil(t.score)
    }
}
