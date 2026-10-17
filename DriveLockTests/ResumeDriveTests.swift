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
        // The first tick after relaunch is not evidence of a stop; a fix showing 0 mph plus
        // iOS saying we're out of the car is.
        XCTAssertEqual(resumed.ingest(DetectorSample(time: t + 3600)), [])
        let events = resumed.ingest(DetectorSample(time: t + 3601, speed: 0, isAutomotive: false))

        guard case .driveEnded(let start, let end, let meters)? = events.first else {
            return XCTFail("resumed drive should end once a fresh sample shows we stopped, got \(events)")
        }
        XCTAssertEqual(start, saved.since)
        XCTAssertEqual(end, saved.lastMoving, "end is the last movement before the app died")
        XCTAssertEqual(meters, saved.meters)
    }

    func testNoActiveDriveWhenIdle() {
        XCTAssertNil(DriveDetector().activeDrive)
    }
}
