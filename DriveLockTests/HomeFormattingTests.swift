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
}
