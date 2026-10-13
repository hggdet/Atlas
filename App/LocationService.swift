import Foundation
import CoreLocation

/// Thin CLLocationManager wrapper. One-shot + continuous updates,
/// published for SwiftUI. Navigation-grade tracking lands with Ferrostar.
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorization = manager.authorizationStatus
    }

    func requestAndStart() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let last = locations.last { location = last }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Non-fatal: the map still works; the user dot simply stays hidden.
    }
}
