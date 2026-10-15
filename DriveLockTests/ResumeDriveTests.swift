import XCTest
@testable import DriveLock

/// A drive in progress must survive iOS killing and relaunching the app.
final class ResumeDriveTests: XCTestCase {
    func testResumedDriveEndsWithOriginalStartAndDistance() throws {
        var d = DriveDetector()
        var t: TimeInterval = 1000
        for _ in 0..<60 {   // 2 min at ~30 mph
            _ = d.ingest(DetectorSample(time: t, speed: 13, isAutomotive: true, distanceDelta: 26))
            t += 2
        }
        let saved = try XCTUnwrap(d.activeDrive)
        let data = try JSONEncoder().encode(saved)

        // App killed; relaunched much later, after the car was parked.
        var resumed = DriveDetector()
        resumed.resume(try JSONDecoder().decode(DriveDetector.ActiveDrive.self, from: data))
        XCTAssertEqual(resumed.state, .driving(since: saved.since))
        let events = resumed.ingest(DetectorSample(time: t + 3600))

        guard case .driveEnded(let start, let end, let meters)? = events.first else {
            return XCTFail("resumed drive should end on the first late sample, got \(events)")
        }
        XCTAssertEqual(start, saved.since)
        XCTAssertEqual(end, saved.lastMoving, "end is the last movement before the app died")
        XCTAssertEqual(meters, saved.meters)
    }

    func testNoActiveDriveWhenIdle() {
        XCTAssertNil(DriveDetector().activeDrive)
    }
}
