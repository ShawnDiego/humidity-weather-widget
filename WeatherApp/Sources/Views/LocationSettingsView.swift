import CoreLocation
import SwiftUI
import WeatherCore

struct LocationSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.locale) private var locale
    @StateObject private var locationManager = LocationPermissionManager()

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSectionHeader(
                            title: loc("定位", "Location"),
                            subtitle: loc(
                                "主 App 获取并保存当前位置，组件直接读取共享位置",
                                "The app stores the latest location, and widgets read it directly"
                            )
                        )

                        AppCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label(loc("定位权限", "Location Permission"), systemImage: "location.fill")
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    StatusBadge(
                                        text: statusText(locationManager.authorizationStatus),
                                        tone: statusTone(locationManager.authorizationStatus)
                                    )
                                }

                                Text(loc(
                                    "若权限未开启，组件会回退到默认城市（北京）。",
                                    "If permission is unavailable, widget falls back to the default city (Beijing)."
                                ))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.72))

                                HStack(spacing: 10) {
                                    Button(loc("请求权限", "Request Permission")) {
                                        locationManager.requestPermission()
                                    }
                                    .buttonStyle(AppSecondaryButtonStyle())

                                    Button(loc("更新当前位置", "Update Current Location")) {
                                        locationManager.refreshLocation()
                                    }
                                    .buttonStyle(AppPrimaryButtonStyle())
                                }
                            }
                        }

                        AppCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(loc("当前保存位置", "Saved Location"), systemImage: "mappin.and.ellipse")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)

                                if let location = model.storedLocation {
                                    ValueRow(label: loc("城市", "City"), value: location.name)
                                    ValueRow(label: loc("纬度", "Latitude"), value: String(format: "%.4f", location.latitude))
                                    ValueRow(label: loc("经度", "Longitude"), value: String(format: "%.4f", location.longitude))
                                    ValueRow(label: loc("时区", "Time Zone"), value: location.timezone)
                                    ValueRow(
                                        label: loc("更新时间", "Updated"),
                                        value: location.updatedAt.formatted(date: .abbreviated, time: .shortened)
                                    )
                                } else {
                                    Text(loc(
                                        "尚未保存定位。点击“更新当前位置”后会同步到组件。",
                                        "No location saved yet. Tap “Update Current Location” to sync widgets."
                                    ))
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.72))
                                }
                            }
                        }

                        if let message = locationManager.errorMessage {
                            AppCard {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                    Text(message)
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.86))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 26)
                    .frame(maxWidth: 960)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(loc("定位", "Location"))
            .onChange(of: locationManager.latestStoredLocation) { _, newLocation in
                guard let newLocation else { return }
                Task {
                    await model.saveLocation(newLocation)
                }
            }
        }
    }

    private func statusText(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways: return loc("始终允许", "Always Allowed")
        case .authorizedWhenInUse: return loc("使用时允许", "When In Use")
        case .denied: return loc("已拒绝", "Denied")
        case .restricted: return loc("受限", "Restricted")
        case .notDetermined: return loc("未决定", "Not Determined")
        @unknown default: return loc("未知", "Unknown")
        }
    }

    private func statusTone(_ status: CLAuthorizationStatus) -> StatusBadge.StatusTone {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return .good
        case .denied:
            return .bad
        case .restricted:
            return .warning
        case .notDetermined:
            return .neutral
        @unknown default:
            return .neutral
        }
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}
