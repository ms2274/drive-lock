import XCTest
@testable import DriveLock

final class PickupRecorderTests: XCTestCase {
    /// 50 Hz accelerometer: phone lying in a mount (gravity on -z), with road vibration.
    private func steady(_ t0: Double, seconds: Double) -> [(t: TimeInterval, x: Double, y: Double, z: Double)] {
        stride(from: 0, to: seconds, by: 0.02).map { dt in
            (t0 + dt, 0.03 * sin(dt * 40), 0.03 * cos(dt * 33), -1.0)
        }
    }

    /// Lifting the phone to read it: gravity swings from -z toward -y over half a second.
    private func lift(_ t0: Double) -> [(t: TimeInterval, x: Double, y: Double, z: Double)] {
        stride(from: 0, to: 0.5, by: 0.02).map { dt in
            let k = dt / 0.5
            return (t0 + dt, 0, -k, -(1 - k))
        } + stride(from: 0.5, to: 5, by: 0.02).map { dt in (t0 + dt, 0, -1, 0) }
    }

    func testSteadyDriveHasNoPickups() {
        XCTAssertEqual(PickupRecorder.countPickups(steady(0, seconds: 120)), 0)
    }

    func testTwoSeparateLiftsAreTwoPickups() {
        var raw = steady(0, seconds: 30)
        raw += lift(30)
        raw += steady(35, seconds: 60)
        raw += lift(95)
        XCTAssertEqual(PickupRecorder.countPickups(raw), 2)
    }

    func testHardBrakingIsNotAPickup() {
        // 0.4 g forward deceleration for 2 s tilts the measured vector ~22°.
        var raw = steady(0, seconds: 10)
        raw += stride(from: 0, to: 2, by: 0.02).map { (10 + $0, 0, 0.4, -1.0) }
        raw += steady(12, seconds: 10)
        XCTAssertEqual(PickupRecorder.countPickups(raw), 0)
    }
}
