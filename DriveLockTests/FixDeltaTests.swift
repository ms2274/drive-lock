import XCTest
@testable import DriveLock

final class FixDeltaTests: XCTestCase {
    func testNormalFixCounts() {
        XCTAssertEqual(DetectionService.fixDelta(meters: 300, seconds: 10), 300)
    }

    func testStaleFixIsIgnored() {
        // Woke up 20 minutes later and 2.3 km away: not driven distance.
        XCTAssertEqual(DetectionService.fixDelta(meters: 2_350, seconds: 1_200), 0)
    }

    func testImpossibleSpeedIsIgnored() {
        XCTAssertEqual(DetectionService.fixDelta(meters: 2_350, seconds: 20), 0)   // 117 m/s
    }

    func testZeroOrNegativeIntervalIsIgnored() {
        XCTAssertEqual(DetectionService.fixDelta(meters: 50, seconds: 0), 0)
        XCTAssertEqual(DetectionService.fixDelta(meters: 50, seconds: -5), 0)
    }

    func testHighwaySpeedStillCounts() {
        XCTAssertEqual(DetectionService.fixDelta(meters: 300, seconds: 10), 300)   // 30 m/s, about 67 mph
    }
}

final class MidDriveGapTests: XCTestCase {
    /// 2026-10-18 log: a 15-minute highway drive was recorded as 0.28 mi because fixes ~5 min
    /// apart were all thrown away.
    func testLongGapCountsDuringADrive() {
        XCTAssertEqual(DetectionService.fixDelta(meters: 8_000, seconds: 300, maxGap: 900), 8_000)
    }

    func testImpossibleSpeedStillRejectedDuringADrive() {
        XCTAssertEqual(DetectionService.fixDelta(meters: 40_000, seconds: 300, maxGap: 900), 0)
    }
}
