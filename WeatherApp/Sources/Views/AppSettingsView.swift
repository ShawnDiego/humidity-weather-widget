import SwiftUI
import WeatherCore

struct AppSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.locale) private var locale

    @State private var apiKey = ""
    @State private var debugShowSource = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppGradientBackground(category: model.currentWeatherCategory, isNight: model.currentWeatherIsNight)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        AppSectionHeader(
                            title: loc("设置", "Settings"),
                            subtitle: loc(
                                "配置和风天气 Key 与调试选项（无 Key 时自动回退 Open-Meteo）",
                                "Configure QWeather key and debug options (fallback to Open-Meteo without key)"
                            )
                        )

                        AppCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(loc("和风天气 API", "QWeather API"), systemImage: "key.fill")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)

                                Group {
#if os(iOS)
                                    TextField(loc("QWeather API Key", "QWeather API Key"), text: $apiKey)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
#else
                                    TextField(loc("QWeather API Key", "QWeather API Key"), text: $apiKey)
#endif
                                }
                                .font(.system(.callout, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                HStack(spacing: 10) {
                                    Button(loc("连通性测试（北京）", "Connectivity Test (Beijing)")) {
                                        Task {
                                            await model.testConnectivity()
                                        }
                                    }
                                    .buttonStyle(AppSecondaryButtonStyle())

                                    Button(loc("保存设置", "Save Settings")) {
                                        saveSettings()
                                    }
                                    .buttonStyle(AppPrimaryButtonStyle())
                                }

                                if !model.statusMessage.isEmpty {
                                    Text(model.statusMessage)
                                        .font(.system(.footnote, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.78))
                                }
                            }
                        }

                        AppCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(loc("调试", "Debug"), systemImage: "ladybug.fill")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)

                                Toggle(loc("组件显示数据来源", "Show Data Source in Widget"), isOn: $debugShowSource)
                                    .toggleStyle(.switch)
                                    .tint(AppPalette.accent)
                                    .foregroundStyle(.white)
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
            .navigationTitle(loc("设置", "Settings"))
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc("保存", "Save")) {
                        saveSettings()
                    }
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    Button(loc("保存", "Save")) {
                        saveSettings()
                    }
                }
#endif
            }
            .onAppear {
                syncFromModel()
            }
            .onChange(of: model.settings) { _, _ in
                syncFromModel()
            }
        }
    }

    private func syncFromModel() {
        apiKey = model.settings.qWeatherAPIKey
        debugShowSource = model.settings.debugShowDataSource
    }

    private func saveSettings() {
        Task {
            await model.saveSettings(
                WeatherSettings(
                    qWeatherAPIKey: apiKey,
                    debugShowDataSource: debugShowSource
                )
            )
        }
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}
