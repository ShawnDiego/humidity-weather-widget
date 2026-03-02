import CoreLocation
import Foundation
import WeatherCore

@MainActor
final class LocationPermissionManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var latestStoredLocation: StoredLocation?
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func refreshLocation() {
        switch authorizationStatus {
        case _ where isAuthorized(authorizationStatus):
            manager.requestLocation()
        case .notDetermined:
            requestPermission()
        default:
            errorMessage = "定位权限未开启，请在系统设置中允许定位。"
        }
    }
}

extension LocationPermissionManager: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized(authorizationStatus) {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task {
            do {
                let placemark = try await geocoder.reverseGeocodeLocation(location).first
                let city = placemark?.locality ?? placemark?.administrativeArea ?? "当前位置"
                let timezone = placemark?.timeZone?.identifier ?? "Asia/Shanghai"
                latestStoredLocation = StoredLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    name: city,
                    timezone: timezone,
                    updatedAt: Date()
                )
                errorMessage = nil
            } catch {
                latestStoredLocation = StoredLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    name: "当前位置",
                    timezone: TimeZone.current.identifier,
                    updatedAt: Date()
                )
                errorMessage = "反向地理编码失败，已保存坐标。"
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "定位失败：\(error.localizedDescription)"
    }

    private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
#if os(macOS)
        return status == .authorized || status == .authorizedAlways
#else
        return status == .authorizedWhenInUse || status == .authorizedAlways
#endif
    }
}
