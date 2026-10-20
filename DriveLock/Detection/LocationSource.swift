import CoreLocation

enum TrackingMode: String { case off, low, high }

/// Battery-aware location wrapper.
/// - off: only significant-change monitoring (wakes a terminated app)
/// - low: coarse accuracy, ~50 m filter, enough to read speed
/// - high: 10 m accuracy while a drive is suspected/active
final class LocationSource: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var mode: TrackingMode = .off
    var onLocations: (([CLLocation]) -> Void)?
    var onSignificantWake: ((CLLocation?) -> Void)?
    var onAuthChange: (() -> Void)?
    var onFenceExit: (() -> Void)?
    /// Diagnostic lines for the event log.
    var onEvent: ((String) -> Void)?

    var authorization: CLAuthorizationStatus { manager.authorizationStatus }
    var backgroundUpdatesAllowed: Bool { manager.allowsBackgroundLocationUpdates }

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        // GPS only runs while a drive is suspected or under way, and iOS never resumes a
        // paused session while the app is in the background, so don't let it pause.
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = false
    }

    func requestAlways() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else { manager.requestAlwaysAuthorization() }
    }

    func startMonitoring() {
        enableBackgroundUpdatesIfAllowed()
        manager.startMonitoringSignificantLocationChanges()
    }

    /// Without this, GPS stops as soon as the app is suspended. Set again whenever permission
    /// changes, since "Always" is usually granted after launch (during onboarding).
    private func enableBackgroundUpdatesIfAllowed() {
        if authorization == .authorizedAlways { manager.allowsBackgroundLocationUpdates = true }
    }

    func setMode(_ new: TrackingMode) {
        guard new != mode else { return }
        onEvent?("GPS \(mode.rawValue) → \(new.rawValue)")
        mode = new
        switch new {
        case .off:
            manager.stopUpdatingLocation()
        case .low:
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.distanceFilter = 50
            manager.startUpdatingLocation()
        case .high:
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            manager.distanceFilter = 10
            manager.startUpdatingLocation()
        }
    }

    private static let fenceID = "parked"

    func monitorFence(around loc: CLLocation, radius: CLLocationDistance) {
        for r in manager.monitoredRegions where r.identifier == Self.fenceID { manager.stopMonitoring(for: r) }
        let region = CLCircularRegion(center: loc.coordinate, radius: radius, identifier: Self.fenceID)
        region.notifyOnEntry = false
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        onEvent?(String(format: "fence set (±%.0f m fix)", loc.horizontalAccuracy))
    }

    // MARK: CLLocationManagerDelegate
    func locationManager(_ m: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == Self.fenceID else { return }
        onEvent?("LEFT parked fence")
        onFenceExit?()
    }
    func locationManager(_ m: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        onEvent?("fence failed: \(error.localizedDescription)")
    }
    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        if mode == .off { onSignificantWake?(locs.last) } else { onLocations?(locs) }
    }
    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        enableBackgroundUpdatesIfAllowed()
        onEvent?("location auth \(authorization.rawValue), background updates \(manager.allowsBackgroundLocationUpdates)")
        onAuthChange?()
    }
    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        onEvent?("location error: \(error.localizedDescription)")
    }
    func locationManagerDidPauseLocationUpdates(_ m: CLLocationManager) {
        onEvent?("iOS PAUSED location updates")
    }
    func locationManagerDidResumeLocationUpdates(_ m: CLLocationManager) {
        onEvent?("iOS resumed location updates")
    }
}
