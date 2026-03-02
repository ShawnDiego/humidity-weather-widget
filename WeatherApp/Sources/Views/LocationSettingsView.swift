import CoreLocation
import SwiftUI
import WeatherCore

struct LocationSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var locationManager = LocationPermissionManager()

    var body: some View {
        NavigationStack {
            Form {
                Section("自动定位") {
                    HStack {
                        Text("权限状态")
                        Spacer()
                        Text(statusText(locationManager.authorizationStatus))
                            .foregroundStyle(.secondary)
                    }

                    Button("请求定位权限") {
                        locationManager.requestPermission()
                    }

                    Button("更新当前位置") {
                        locationManager.refreshLocation()
                    }
                }

                Section("当前保存位置") {
                    if let location = model.storedLocation {
                        LabeledContent("城市", value: location.name)
                        LabeledContent("纬度", value: String(format: "%.4f", location.latitude))
                        LabeledContent("经度", value: String(format: "%.4f", location.longitude))
                        LabeledContent("时区", value: location.timezone)
                        LabeledContent("更新时间", value: location.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    } else {
                        Text("尚未获取定位，组件会回退到北京。")
                            .foregroundStyle(.secondary)
                    }
                }

                if let message = locationManager.errorMessage {
                    Section("提示") {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("定位设置")
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
        case .authorizedAlways: return "始终允许"
        case .authorizedWhenInUse: return "使用时允许"
        case .denied: return "已拒绝"
        case .restricted: return "受限"
        case .notDetermined: return "未决定"
        @unknown default: return "未知"
        }
    }
}
