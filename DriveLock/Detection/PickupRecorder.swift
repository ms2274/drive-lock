import CoreMotion
import Foundation

/// Counts pickups from Apple's sensor recorder, which logs the accelerometer at 50 Hz even while
/// the app is asleep (it is asleep for most of a drive). Data can lag up to 3 minutes, so a
/// drive's count is settled a little after the drive ends.
struct PickupRecorder {
    struct Result: Equatable {
        var pickups: Int
        var samples: Int
        /// Data reaches the end of the drive; otherwise it hasn't all arrived yet.
        var complete: Bool
    }

    static var isAvailable: Bool { CMSensorRecorder.isAccelerometerRecordingAvailable() }

    private static let lastStartKey = "pickupRecorder.lastStart"
    private static let recordSeconds: TimeInterval = 12 * 3600

    /// Keep recording. Each request covers up to 12 h, so renew when half of it has gone by.
    static func keepRecording(defaults: UserDefaults = .standard) -> Bool {
        guard isAvailable else { return false }
        let last = defaults.object(forKey: lastStartKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > recordSeconds / 2 else { return false }
        CMSensorRecorder().recordAccelerometer(forDuration: recordSeconds)
        defaults.set(Date(), forKey: lastStartKey)
        return true
    }

    /// Runs off the main thread: a drive can be tens of thousands of samples.
    static func count(from start: Date, to end: Date) async -> Result? {
        guard isAvailable else { return nil }
        return await Task.detached(priority: .utility) { () -> Result? in
            guard let list = CMSensorRecorder().accelerometerData(from: start, to: end) else { return nil }
            var samples: [(Date, CMAcceleration)] = []
            for case let d as CMRecordedAccelerometerData in list { samples.append((d.startDate, d.acceleration)) }
            let pickups = countPickups(samples.map { ($0.0.timeIntervalSinceReferenceDate, $0.1.x, $0.1.y, $0.1.z) })
            let complete = (samples.last?.0).map { end.timeIntervalSince($0) < 10 } ?? false
            return Result(pickups: pickups, samples: samples.count, complete: complete)
        }.value
    }

    /// Smooth raw 50 Hz acceleration into the direction of gravity, thin it to 10 Hz, and run the
    /// same pickup rule the live sensor uses. Braking and turns tilt the vector far less than 35°.
    static func countPickups(_ raw: [(t: TimeInterval, x: Double, y: Double, z: Double)],
                             config: PickupConfig = .default) -> Int {
        var detector = PickupDetector(config: config)
        var g: (x: Double, y: Double, z: Double)?
        for (i, s) in raw.enumerated() {
            let a = 0.15
            g = g.map { ($0.x + a * (s.x - $0.x), $0.y + a * (s.y - $0.y), $0.z + a * (s.z - $0.z)) } ?? (s.x, s.y, s.z)
            guard i % 5 == 0, let v = g else { continue }
            detector.ingest(GravitySample(time: s.t, x: v.x, y: v.y, z: v.z))
        }
        return detector.count
    }
}

/// CMSensorDataList only offers Objective-C fast enumeration.
extension CMSensorDataList: @retroactive Sequence {
    public func makeIterator() -> NSFastEnumerationIterator { NSFastEnumerationIterator(self) }
}
