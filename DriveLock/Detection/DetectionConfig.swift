import Foundation

/// All tunables for driving detection. Speeds in m/s, durations in seconds.
struct DetectionConfig: Equatable {
    /// ~10 mph. Speed required (with automotive) to start a drive.
    var startSpeed: Double = 4.47
    /// Automotive + speed must hold this long before a drive is confirmed.
    var startConfirmSeconds: TimeInterval = 30
    /// Conditions may drop this long during confirmation before we give up.
    var suspectGraceSeconds: TimeInterval = 20
    /// Above this (~5 mph) counts as "moving".
    var movingSpeed: Double = 2.24
    /// No movement for this long ends the drive, even if iOS still says "automotive" (Mike, 2026-10-15:
    /// shields are for moving, not for sitting in a parked car). Stops longer than this split the trip.
    var stopEndSeconds: TimeInterval = 60
    /// A tick arriving this long after the previous sample means iOS had the app asleep.
    /// That gap is missing data, not proof the car stopped, so the tick is ignored.
    var staleGapSeconds: TimeInterval = 45
    /// When iOS's motion history says "automotive" for longer than the confirm time,
    /// a drive is back-dated to when that began, but never further back than this.
    var maxBackdateSeconds: TimeInterval = 300
    /// iOS saying "automotive" without a break for this long starts a drive even with no GPS speed
    /// yet (Mike, 2026-10-19: speed over certainty; passengers tap "I'm a passenger").
    var motionOnlyStartSeconds: TimeInterval = 60
    /// Ignore location fixes worse than this (meters).
    var maxHorizontalAccuracy: Double = 50
    /// Trips shorter than this are discarded by consumers (meters).
    var minTripMeters: Double = 400

    static let `default` = DetectionConfig()
}
