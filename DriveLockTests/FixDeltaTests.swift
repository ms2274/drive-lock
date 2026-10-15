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
