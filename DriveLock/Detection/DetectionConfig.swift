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
    /// No movement for this long ends the drive (survives red lights).
    var stopEndSeconds: TimeInterval = 300
    /// If still classified automotive while stationary, end after this long anyway.
    var hardStopSeconds: TimeInterval = 600
    /// Ignore location fixes worse than this (meters).
    var maxHorizontalAccuracy: Double = 50
    /// Trips shorter than this are discarded by consumers (meters).
    var minTripMeters: Double = 400

    static let `default` = DetectionConfig()
}
