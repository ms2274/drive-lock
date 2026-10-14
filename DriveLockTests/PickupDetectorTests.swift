import XCTest
@testable import DriveLock

final class PickupDetectorTests: XCTestCase {
    /// Gravity for a phone tilted `deg` degrees about its x axis (0 = lying flat).
    private func g(_ t: Double, tilt deg: Double) -> GravitySample {
        let r = deg * .pi / 180
        return GravitySample(time: t, x: 0, y: sin(r), z: -cos(r))
    }

    private func run(_ samples: [GravitySample]) -> Int {
        var d = PickupDetector()
        samples.forEach { d.ingest($0) }
        return d.count
    }

    /// Ten samples a second, holding `deg`, from t0 for `seconds`.
    private func hold(_ deg: Double, from t0: Double, for seconds: Double) -> [GravitySample] {
        stride(from: 0.0, to: seconds, by: 0.1).map { g(t0 + $0, tilt: deg) }
    }

    func testPhoneLyingStillIsNoPickup() {
        XCTAssertEqual(run(hold(0, from: 0, for: 60)), 0)
    }

    func testQuickLiftIsOnePickup() {
        let s = hold(0, from: 0, for: 10) + hold(50, from: 10, for: 5)
        XCTAssertEqual(run(s), 1)
    }

    func testSlowTiltIsNotAPickup() {
        // 45 degrees spread over 60 seconds, like a long hill.
        let s = stride(from: 0.0, to: 60, by: 0.1).map { g($0, tilt: 45 * $0 / 60) }
        XCTAssertEqual(run(s), 0)
    }

    func testSmallJostleIsNotAPickup() {
        let s = stride(from: 0.0, to: 30, by: 0.1).map { g($0, tilt: ($0.truncatingRemainder(dividingBy: 1) < 0.5) ? 0 : 10) }
        XCTAssertEqual(run(s), 0)
    }

    func testPickUpThenPutDownIsOnePickup() {
        let s = hold(0, from: 0, for: 10) + hold(50, from: 10, for: 5) + hold(0, from: 15, for: 5)
        XCTAssertEqual(run(s), 1)
    }

    func testPickupsFarApartAreTwo() {
        let s = hold(0, from: 0, for: 10) + hold(50, from: 10, for: 2)
            + hold(50, from: 12, for: 40)                      // held steady
            + hold(0, from: 52, for: 2) + hold(0, from: 54, for: 30)
            + hold(50, from: 84, for: 2)
        XCTAssertGreaterThanOrEqual(run(s), 2)
    }

    func testRepeatPickupAfterQuietWindowCountsAgain() {
        // Lift, put down, wait 12 s, lift again: two pickups with a 10 s window.
        let s = hold(0, from: 0, for: 10) + hold(50, from: 10, for: 1) + hold(0, from: 11, for: 12)
            + hold(50, from: 23, for: 1)
        XCTAssertEqual(run(s), 2)
    }

    func testZeroVectorDoesNotCrashOrCount() {
        let zero = (0..<20).map { GravitySample(time: Double($0) * 0.1, x: 0, y: 0, z: 0) }
        XCTAssertEqual(run(zero), 0)
    }

    func testResetClearsCount() {
        var d = PickupDetector()
        (hold(0, from: 0, for: 5) + hold(60, from: 5, for: 2)).forEach { d.ingest($0) }
        XCTAssertEqual(d.count, 1)
        d.reset()
        XCTAssertEqual(d.count, 0)
    }
}
