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
    var onSignificantWake: (() -> Void)?
    var onAuthChange: (() -> Void)?

    var authorization: CLAuthorizationStatus { manager.authorizationStatus }

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = true
        manager.showsBackgroundLocationIndicator = false
    }

    func requestAlways() {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        else { manager.requestAlwaysAuthorization() }
    }

    func startMonitoring() {
        if authorization == .authorizedAlways { manager.allowsBackgroundLocationUpdates = true }
        manager.startMonitoringSignificantLocationChanges()
    }

    func setMode(_ new: TrackingMode) {
        guard new != mode else { return }
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

    // MARK: CLLocationManagerDelegate
    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        if mode == .off { onSignificantWake?() } else { onLocations?(locs) }
    }
    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) { onAuthChange?() }
    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}
}
