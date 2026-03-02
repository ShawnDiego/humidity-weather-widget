import SwiftUI
import WeatherCore

struct AppSettingsView: View {
    @EnvironmentObject private var model: AppModel

    @State private var apiKey = ""
    @State private var debugShowSource = false

    var body: some View {
        NavigationStack {
            Form {
                Section("和风天气") {
                    Group {
                        #if os(iOS)
                        TextField("QWeather API Key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        #else
                        TextField("QWeather API Key", text: $apiKey)
                        #endif
                    }

                    Button("测试连通性（北京）") {
                        Task {
                            await model.testConnectivity()
                        }
                    }

                    if !model.statusMessage.isEmpty {
                        Text(model.statusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("调试") {
                    Toggle("组件显示数据来源", isOn: $debugShowSource)
                }
            }
            .navigationTitle("应用设置")
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        Task {
                            await model.saveSettings(
                                WeatherSettings(
                                    qWeatherAPIKey: apiKey,
                                    debugShowDataSource: debugShowSource
                                )
                            )
                        }
                    }
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    Button("保存") {
                        Task {
                            await model.saveSettings(
                                WeatherSettings(
                                    qWeatherAPIKey: apiKey,
                                    debugShowDataSource: debugShowSource
                                )
                            )
                        }
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
}
