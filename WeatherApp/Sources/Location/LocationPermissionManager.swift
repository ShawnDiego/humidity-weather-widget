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
            errorMessage = loc(
                "定位权限未开启，请在系统设置中允许定位。",
                "Location permission is disabled. Please enable it in system settings."
            )
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
                let city = placemark?.locality ?? placemark?.administrativeArea ?? loc("当前位置", "Current Location")
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
                    name: loc("当前位置", "Current Location"),
                    timezone: TimeZone.current.identifier,
                    updatedAt: Date()
                )
                errorMessage = loc(
                    "反向地理编码失败，已保存坐标。",
                    "Reverse geocoding failed, coordinates were saved."
                )
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = localizedLocationErrorMessage(error)
    }

    private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
#if os(macOS)
        return status == .authorized || status == .authorizedAlways
#else
        return status == .authorizedWhenInUse || status == .authorizedAlways
#endif
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem() ? zh : en
    }

    private func localizedLocationErrorMessage(_ error: Error) -> String {
        guard let error = error as? CLError else {
            return loc("定位失败，请稍后重试。", "Location failed. Please try again.")
        }

        switch error.code {
        case .denied:
            return loc("定位权限未开启，请在系统设置中允许定位。", "Location permission is disabled. Please enable it in system settings.")
        case .locationUnknown:
            return loc("暂时无法确定当前位置，请稍后重试。", "Current location is temporarily unavailable. Please try again.")
        case .network:
            return loc("定位网络请求失败，请检查网络后重试。", "Location network request failed. Check your connection and try again.")
        case .headingFailure:
            return loc("设备暂时无法提供定位方向信息。", "The device cannot provide heading information right now.")
        default:
            return loc("定位失败，请稍后重试。", "Location failed. Please try again.")
        }
    }
}
