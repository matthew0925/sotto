import Foundation
import CoreLocation
import Combine

/// Keeps a refreshed location fix while a check-in timer is running, so that if
/// the timeout fires (or the user manually sends an alert), the SMS carries a
/// location that's close to real-time rather than wherever the user was when
/// they started the check-in.
///
/// iOS constraint (see 技術仕様書 §4/§6): sustained *background* tracking needs
/// "Always" location authorization, which Apple reviews strictly and which this
/// app does not request — only "When In Use" (`requestWhenInUseAuthorization`).
/// Practically this means: updates stay fresh while the app is foreground or
/// briefly backgrounded, but if the user locks the phone and it stays locked for
/// a while, updates pause until they reopen the app. That gap is real and is not
/// solved here — documented as a known limitation, not silently glossed over.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var isTracking = false

    private static let intervalKey = "sotto.location.updateInterval"
    /// User-configurable minimum time between accepted fixes (Settingsタブから変更可能).
    /// Persisted across launches; defaults to 2 minutes. A shorter interval means
    /// fresher location data at the cost of more battery/GPS radio use.
    @Published var updateInterval: TimeInterval {
        didSet { UserDefaults.standard.set(updateInterval, forKey: Self.intervalKey) }
    }

    override init() {
        let saved = UserDefaults.standard.double(forKey: Self.intervalKey)
        updateInterval = saved > 0 ? saved : 120
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 30
    }

    func requestPermission() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Call when a check-in timer starts. Stop with `stopTracking()` once the
    /// user marks themselves safe.
    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        if authorizationStatus == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.pausesLocationUpdatesAutomatically = false
        }
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        if let last = lastUpdated, let previous = lastLocation,
           Date().timeIntervalSince(last) < updateInterval,
           latest.distance(from: previous) < self.manager.distanceFilter {
            return
        }
        lastLocation = latest
        lastUpdated = Date()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastErrorMessage = error.localizedDescription
    }

    /// Surfaced so CheckInView can stop showing "取得中…" forever when the user
    /// has denied location access — previously a silent failure with no UI signal.
    @Published private(set) var lastErrorMessage: String?

    /// True once we know for certain updates cannot happen (as opposed to
    /// `.notDetermined`, which just means the prompt hasn't been answered yet).
    var isPermissionDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Best available fix, formatted for dropping straight into an SMS body.
    var mapsLink: String? {
        guard let loc = lastLocation else { return nil }
        return "https://maps.apple.com/?ll=\(loc.coordinate.latitude),\(loc.coordinate.longitude)"
    }
}
