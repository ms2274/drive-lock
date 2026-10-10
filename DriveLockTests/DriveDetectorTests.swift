import XCTest
@testable import DriveLock

final class DriveDetectorTests: XCTestCase {
    private func run(_ s: Scenario) -> [DetectorEvent] {
        var d = DriveDetector()
        return s.samples().flatMap { d.ingest($0) }
    }

    func testAllScenariosMatchExpectation() {
        for s in Scenario.all {
            let events = run(s)
            let starts = events.filter { if case .driveStarted = $0 { return true } else { return false } }
            let ends = events.filter { if case .driveEnded = $0 { return true } else { return false } }
            XCTAssertEqual(starts.count, s.expectsDrive ? 1 : 0, s.name)
            XCTAssertEqual(ends.count, s.expectsDrive ? 1 : 0, s.name)
        }
    }

    func testRedLightDoesNotEndTrip() {
        let s = Scenario.all[0]
        let ends = run(s).filter { if case .driveEnded = $0 { return true } else { return false } }
        XCTAssertEqual(ends.count, 1, "red light must not split the trip")
    }

    func testEndTimeIsWhenMovementStoppedNotWhenDebounceExpired() {
        let s = Scenario(name: "t", segments: [
            .init(seconds: 120, speed: 13, automotive: true),
            .init(seconds: 400, speed: 0, automotive: false)], expectsDrive: true)
        guard case .driveEnded(_, let end, _)? = run(s).first(where: { if case .driveEnded = $0 { return true } else { return false } })
        else { return XCTFail("no end") }
        XCTAssertEqual(end, 120, accuracy: 2)
    }

    func testStartIsBackdatedToSuspectedTime() {
        guard case .driveStarted(let at)? = run(Scenario.all[0]).first(where: { if case .driveStarted = $0 { return true } else { return false } })
        else { return XCTFail("no start") }
        XCTAssertEqual(at, 1, accuracy: 1)
    }

    func testDistanceAccumulates() {
        let s = Scenario(name: "t", segments: [
            .init(seconds: 100, speed: 10, automotive: true),
            .init(seconds: 400, speed: 0, automotive: false)], expectsDrive: true)
        guard case .driveEnded(_, _, let m)? = run(s).first(where: { if case .driveEnded = $0 { return true } else { return false } })
        else { return XCTFail("no end") }
        XCTAssertEqual(m, 1000, accuracy: 20)
    }

    func testInvalidSpeedDoesNotStartDrive() {
        var d = DriveDetector()
        var ev: [DetectorEvent] = []
        for t in 1...120 { ev += d.ingest(DetectorSample(time: Double(t), speed: nil, isAutomotive: true)) }
        XCTAssertTrue(ev.isEmpty)
    }
}
