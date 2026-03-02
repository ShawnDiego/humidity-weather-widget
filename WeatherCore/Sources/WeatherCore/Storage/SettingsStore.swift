import Foundation

public actor SettingsStore {
    private let defaults: UserDefaults
    private let storageKey = "weather_settings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init() {
        self.defaults = SharedContainer.userDefaults()
    }

    public func load() -> WeatherSettings {
        guard let data = defaults.data(forKey: storageKey),
              let settings = try? decoder.decode(WeatherSettings.self, from: data)
        else {
            return WeatherSettings()
        }
        return settings
    }

    public func save(_ settings: WeatherSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public func updateQWeatherAPIKey(_ key: String) {
        var settings = load()
        settings.qWeatherAPIKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        save(settings)
    }

    public func updateDebugSource(_ enabled: Bool) {
        var settings = load()
        settings.debugShowDataSource = enabled
        save(settings)
    }
}
