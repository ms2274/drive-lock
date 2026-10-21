import Foundation

/// Scripted sensor data for replay in tests and the debug screen.
/// Each segment is (seconds, speed m/s, automotive). One sample per second.
struct Scenario {
    struct Segment { let seconds: Int; let speed: Double; let automotive: Bool }
    let name: String
    let segments: [Segment]
    /// What a correct detector should report.
    let expectsDrive: Bool

    func samples(startingAt t0: TimeInterval = 0) -> [DetectorSample] {
        var out: [DetectorSample] = []
        var t = t0
        for seg in segments {
            for _ in 0..<seg.seconds {
                t += 1
                out.append(DetectorSample(time: t, speed: seg.speed,
                                          isAutomotive: seg.automotive,
                                          distanceDelta: seg.speed))
            }
        }
        return out
    }

    static let mph10: Double = 4.47, mph30: Double = 13.4, mph60: Double = 26.8

    static let all: [Scenario] = [
        Scenario(name: "Normal drive with 40 s red light", segments: [
            .init(seconds: 600, speed: mph30, automotive: true),
            .init(seconds: 40, speed: 0, automotive: true),
            .init(seconds: 600, speed: mph30, automotive: true),
            .init(seconds: 400, speed: 0, automotive: false)], expectsDrive: true),
        Scenario(name: "Stop-and-go traffic (40 s stops)", segments: [
            .init(seconds: 120, speed: mph30, automotive: true),
            .init(seconds: 40, speed: 0, automotive: true),
            .init(seconds: 120, speed: mph30, automotive: true),
            .init(seconds: 40, speed: 0, automotive: true),
            .init(seconds: 120, speed: mph30, automotive: true),
            .init(seconds: 400, speed: 0, automotive: false)], expectsDrive: true),
        Scenario(name: "Bike ride (fast, not automotive)", segments: [
            .init(seconds: 900, speed: 6, automotive: false)], expectsDrive: false),
        Scenario(name: "Bus-stop dither (automotive blips)", segments: [
            .init(seconds: 10, speed: 5, automotive: true),
            .init(seconds: 60, speed: 0, automotive: false),
            .init(seconds: 10, speed: 5, automotive: true),
            .init(seconds: 60, speed: 0, automotive: false)], expectsDrive: false),
        Scenario(name: "Parked, engine on (automotive sticks)", segments: [
            .init(seconds: 300, speed: mph30, automotive: true),
            .init(seconds: 700, speed: 0, automotive: true)], expectsDrive: true),
        Scenario(name: "Short hop (drive then park)", segments: [
            .init(seconds: 45, speed: mph30, automotive: true),
            .init(seconds: 400, speed: 0, automotive: false)], expectsDrive: true),
    ]
}
