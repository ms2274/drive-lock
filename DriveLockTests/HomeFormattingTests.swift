import XCTest
@testable import DriveLock

final class HomeFormattingTests: XCTestCase {
    func testTodayAndYesterdayAreNamed() {
        let now = Date()
        XCTAssertTrue(HomeView.when(now).hasPrefix("Today, "))
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertTrue(HomeView.when(yesterday).hasPrefix("Yesterday, "))
    }

    func testOlderDatesShowMonthAndDay() {
        let old = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 7, minute: 5))!
        let s = HomeView.when(old)
        XCTAssertFalse(s.hasPrefix("Today") || s.hasPrefix("Yesterday"))
        XCTAssertTrue(s.contains("9"))
    }

    func testDurationFormatting() {
        XCTAssertEqual(HomeView.duration(0), "0m")
        XCTAssertEqual(HomeView.duration(42 * 60), "42m")
        XCTAssertEqual(HomeView.duration((4 * 60 + 32) * 60), "4h 32m")
    }
}
