import XCTest
@testable import DriveLock

/// From real drive logs (2026-10-17): iOS woke the app for only a few seconds about every
/// 5 minutes, so detection can't rely on watching 30 s of driving or a full minute of stop.
final class SleepyAppTests: XCTestCase {
    private func started(_ e: [DetectorEvent]) -> TimeInterval? {
        for x in e { if case .driveStarted(let at) = x { return at } }
        return nil
    }
    private func ended(_ e: [DetectorEvent]) -> Bool {
        e.contains { if case .driveEnded = $0 { return true } else { return false } }
    }

    /// The pattern in the log: each wake is a late tick, an "automotive" update and one fix at speed.
    func testDriveStartsByTheSecondShortWake() {
        var d = DriveDetector()
        var events: [DetectorEvent] = []
        for wake in 0..<3 {
            let t = 1000 + Double(wake) * 300
            events += d.ingest(DetectorSample(time: t))
            events += d.ingest(DetectorSample(time: t, isAutomotive: true))
            events += d.ingest(DetectorSample(time: t + 1, speed: 16))
        }
        XCTAssertEqual(started(events) ?? -1, 1000, accuracy: 1, "back-dated to the first wake")
    }

    func testMotionHistoryStartsDriveOnTheFirstWake() {
        var d = DriveDetector()
        var e = d.ingest(DetectorSample(time: 5000, isAutomotive: true, automotiveSince: 5000 - 120))
        e += d.ingest(DetectorSample(time: 5001, speed: 9))
        XCTAssertEqual(started(e) ?? -1, 4880, accuracy: 0.1)
    }

    func testBackdateIsCapped() {
        var d = DriveDetector()
        let e = d.ingest(DetectorSample(time: 5000, isAutomotive: true, automotiveSince: 5000 - 3600))
        XCTAssertEqual(started(e) ?? -1, 5000 - 300, accuracy: 0.1)
    }

    func testShortAutomotiveHistoryStillNeedsConfirmation() {
        var d = DriveDetector()
        _ = d.ingest(DetectorSample(time: 5000, isAutomotive: true, automotiveSince: 5000 - 10))
        XCTAssertNil(started(d.ingest(DetectorSample(time: 5001, speed: 9))))
    }

    /// 16:51 in the log: the app slept 4 minutes mid-drive and the drive was ended at 30 mph.
    func testSleepingMidDriveDoesNotEndTheDrive() {
        var d = DriveDetector()
        var events: [DetectorEvent] = []
        for t in 1...120 { events += d.ingest(DetectorSample(time: Double(t), speed: 13, isAutomotive: true)) }
        XCTAssertNotNil(started(events))
        events = d.ingest(DetectorSample(time: 360))                       // overdue tick on wake
        events += d.ingest(DetectorSample(time: 360, isAutomotive: true))  // motion update on wake
        events += d.ingest(DetectorSample(time: 361, speed: 13))
        XCTAssertFalse(ended(events))
    }

    func testWakingAfterParkingEndsAtLastMovement() {
        var d = DriveDetector()
        for t in 1...120 { _ = d.ingest(DetectorSample(time: Double(t), speed: 13, isAutomotive: true)) }
        XCTAssertEqual(d.ingest(DetectorSample(time: 2000)), [])          // stale tick ignored
        let e = d.ingest(DetectorSample(time: 2000, isAutomotive: false))  // iOS: walking now
        guard case .driveEnded(_, let end, _)? = e.first else { return XCTFail("no end: \(e)") }
        XCTAssertEqual(end, 120, accuracy: 1)
    }

    func testStopAtLightJustAfterWakingDoesNotEndDrive() {
        var d = DriveDetector()
        for t in 1...120 { _ = d.ingest(DetectorSample(time: Double(t), speed: 13, isAutomotive: true)) }
        // Wake 5 minutes later stopped at a light, still "automotive": only 10 s of stop watched.
        _ = d.ingest(DetectorSample(time: 420))
        let e = d.ingest(DetectorSample(time: 430, speed: 0, isAutomotive: true))
        XCTAssertFalse(ended(e))
    }
}

final class MotionOnlyStartTests: XCTestCase {
    private func started(_ e: [DetectorEvent]) -> TimeInterval? {
        for x in e { if case .driveStarted(let at) = x { return at } }
        return nil
    }

    func testAMinuteOfAutomotiveStartsWithoutAnySpeed() {
        var d = DriveDetector()
        let e = d.ingest(DetectorSample(time: 5000, isAutomotive: true, automotiveSince: 5000 - 70))
        XCTAssertEqual(started(e) ?? -1, 4930, accuracy: 0.1)
    }

    func testUnderAMinuteOfAutomotiveWithoutSpeedWaits() {
        var d = DriveDetector()
        XCTAssertNil(started(d.ingest(DetectorSample(time: 5000, isAutomotive: true, automotiveSince: 5000 - 40))))
    }

    func testParkedWithEngineOnDoesNotRestartAfterDriveEnds() {
        var d = DriveDetector()
        var starts = 0
        for t in 1...300 { if started(d.ingest(DetectorSample(time: Double(t), speed: 13, isAutomotive: true))) != nil { starts += 1 } }
        // Parked 10 minutes, iOS still says automotive the whole time.
        for t in 301...900 { if started(d.ingest(DetectorSample(time: Double(t), speed: 0, isAutomotive: true))) != nil { starts += 1 } }
        XCTAssertEqual(starts, 1)
    }

    func testNewAutomotiveStretchAfterParkingCanStartAgain() {
        var d = DriveDetector()
        for t in 1...300 { _ = d.ingest(DetectorSample(time: Double(t), speed: 13, isAutomotive: true)) }
        for t in 301...400 { _ = d.ingest(DetectorSample(time: Double(t), speed: 0, isAutomotive: false)) }
        let e = d.ingest(DetectorSample(time: 1000, isAutomotive: true, automotiveSince: 900))
        XCTAssertEqual(started(e) ?? -1, 900, accuracy: 0.1)
    }
}
