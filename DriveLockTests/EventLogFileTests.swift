import XCTest
@testable import DriveLock

final class EventLogFileTests: XCTestCase {
    private func tempLog(maxBytes: Int = 512 * 1024) -> EventLogFile {
        var f = EventLogFile(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("events-\(UUID().uuidString).log"))
        f.maxBytes = maxBytes
        return f
    }

    func testAppendsAndReadsBackNewestLast() {
        let f = tempLog()
        defer { f.clear() }
        f.append("one"); f.append("two"); f.append("three")
        XCTAssertEqual(f.lines(last: 2), ["two", "three"])
    }

    func testTrimsOldestHalfWhenTooBig() {
        let f = tempLog(maxBytes: 100)
        defer { f.clear() }
        for i in 0..<30 { f.append("line \(i)") }
        let lines = f.lines(last: 1000)
        XCTAssertLessThan(lines.count, 30)
        XCTAssertEqual(lines.last, "line 29")
    }

    func testClearEmptiesLog() {
        let f = tempLog()
        f.append("x"); f.clear()
        XCTAssertEqual(f.lines(last: 10), [])
    }
}
