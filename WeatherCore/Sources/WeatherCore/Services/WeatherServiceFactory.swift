import Foundation

public struct WeatherServiceFactory {
    public let profileStore: DisplayProfileStore
    public let widgetConfigStore: WidgetConfigStore
    public let snapshotCacheStore: SnapshotCacheStore
    public let settingsStore: SettingsStore
    public let locationStore: LocationStore
    private let networkClient: NetworkClient

    public init(
        cacheStore: SnapshotCacheStore = SnapshotCacheStore(),
        networkClient: NetworkClient = URLSessionNetworkClient()
    ) {
        self.profileStore = DisplayProfileStore()
        self.widgetConfigStore = WidgetConfigStore()
        self.snapshotCacheStore = cacheStore
        self.settingsStore = SettingsStore()
        self.locationStore = LocationStore()
        self.networkClient = networkClient
    }

    public func loadSettings() async -> WeatherSettings {
        await settingsStore.load()
    }

    public func makeWeatherProvider(settings: WeatherSettings) -> WeatherProvider {
        let primary: WeatherProvider?
        if settings.qWeatherAPIKey.isEmpty {
            primary = nil
        } else {
            primary = QWeatherProvider(apiKey: settings.qWeatherAPIKey, network: networkClient)
        }

        let secondary = OpenMeteoProvider(network: networkClient)
        return CompositeWeatherProvider(primary: primary, secondary: secondary)
    }

    public func makeCityGeocoder(settings: WeatherSettings) -> CityGeocoder {
        let primary: CityGeocoder?
        if settings.qWeatherAPIKey.isEmpty {
            primary = nil
        } else {
            primary = QWeatherCityGeocoder(apiKey: settings.qWeatherAPIKey, network: networkClient)
        }

        return CompositeCityGeocoder(primary: primary, secondary: OpenMeteoCityGeocoder(network: networkClient))
    }

    public func makeRepository(settings: WeatherSettings) -> WeatherRepository {
        WeatherRepository(
            provider: makeWeatherProvider(settings: settings),
            cacheStore: snapshotCacheStore,
            ttl: AppConfig.cacheTTL,
            staleWindow: AppConfig.staleWindow
        )
    }

    public func resolveLocation(
        mode: LocationMode,
        manualCity: String?,
        manualCoordinates: (lat: Double, lon: Double)? = nil
    ) async throws -> ResolvedLocation {
        let settings = await loadSettings()
        switch mode {
        case .current:
            if let stored = await locationStore.load() {
                return stored.asResolvedLocation
            }
            return .beijingFallback
        case .manualCity:
            if let manualCoordinates {
                let cityName = manualCity?.isEmpty == false ? manualCity! : "手动城市"
                return ResolvedLocation(
                    name: cityName,
                    latitude: manualCoordinates.lat,
                    longitude: manualCoordinates.lon,
                    timezone: "Asia/Shanghai"
                )
            }

            guard let manualCity, !manualCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WeatherError.cityNotFound("(空)")
            }

            let geocoder = makeCityGeocoder(settings: settings)
            let resolved = try await geocoder.resolveCity(manualCity)
            return ResolvedLocation(name: resolved.name, latitude: resolved.lat, longitude: resolved.lon, timezone: resolved.tz)
        }
    }
}
