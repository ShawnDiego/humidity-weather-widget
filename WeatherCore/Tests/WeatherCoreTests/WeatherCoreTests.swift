import Foundation
import Testing
@testable import WeatherCore

struct WeatherCoreTests {
    @Test
    func displayProfileDeduplicatesMetrics() {
        let profile = DisplayProfile(
            name: "A",
            metrics: [.temperature, .humidity, .temperature, .windSpeed],
            unitSystem: .metric
        )

        #expect(profile.metrics == [.temperature, .humidity, .windSpeed])
    }

    @Test
    func cacheFreshnessRespectsTTLAndStaleWindow() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let cache = SnapshotCacheStore(cacheDirectory: tempDir)
        let snapshot = WeatherSnapshot(
            timestamp: Date(),
            timezone: "Asia/Shanghai",
            locationName: "北京",
            values: [.temperature: 20],
            conditionCode: "100",
            sunrise: nil,
            sunset: nil,
            source: "Test"
        )

        let key = "beijing"
        let now = Date()
        await cache.save(snapshot: snapshot, key: key, at: now.addingTimeInterval(-45 * 60))

        let stale = await cache.freshness(for: key, now: now, ttl: 30 * 60, staleWindow: 3 * 60 * 60)
        #expect(stale?.freshness == .stale)

        await cache.save(snapshot: snapshot, key: key, at: now)
        let live = await cache.freshness(for: key, now: now, ttl: 30 * 60, staleWindow: 3 * 60 * 60)
        #expect(live?.freshness == .live)
    }

    @Test
    func compositeProviderMergesMissingMetricsFromFallback() async throws {
        let primary = MockWeatherProvider(snapshot: WeatherSnapshot(
            timestamp: Date(),
            timezone: "Asia/Shanghai",
            locationName: "北京",
            values: [.temperature: 25],
            conditionCode: "100",
            sunrise: nil,
            sunset: nil,
            source: "QWeather"
        ))

        let fallback = MockWeatherProvider(snapshot: WeatherSnapshot(
            timestamp: Date(),
            timezone: "Asia/Shanghai",
            locationName: "北京",
            values: [.temperature: 20, .solarIrradiance: 600],
            conditionCode: "1",
            sunrise: nil,
            sunset: nil,
            source: "Open-Meteo"
        ))

        let provider = CompositeWeatherProvider(primary: primary, secondary: fallback)
        let result = try await provider.fetchCurrent(lat: 39.9, lon: 116.4, tz: "Asia/Shanghai")

        #expect(result.values[.temperature] == 25)
        #expect(result.values[.solarIrradiance] == 600)
    }

    @Test
    func formatterSupportsUnitAndLanguageLocalization() {
        let us = Locale(identifier: "en_US")
        let zh = Locale(identifier: "zh_Hans_CN")

        let imperialTemp = WeatherFormatter.formattedValue(
            metric: .temperature,
            value: 22,
            unitSystem: .imperial,
            locale: us
        )

        #expect(imperialTemp.contains("°F"))
        #expect(WeatherFormatter.localizedMetricName(.humidity, locale: us) == "Humidity")
        #expect(WeatherFormatter.localizedMetricName(.humidity, locale: zh) == "湿度")
        #expect(WeatherFormatter.localizedUnitSystemName(.metric, locale: us).contains("Metric"))
    }

    @Test
    func formatterMapsConditionToLocalizedDescriptionAndSymbols() {
        let en = Locale(identifier: "en_US")
        let zh = Locale(identifier: "zh_Hans_CN")

        #expect(WeatherFormatter.conditionDescription(for: "95", locale: en) == "Thunderstorm")
        #expect(WeatherFormatter.conditionDescription(for: "302", locale: zh) == "雷暴")
        #expect(WeatherFormatter.weatherSymbol(for: "0", isNight: false) == "sun.max.fill")
        #expect(WeatherFormatter.weatherSymbol(for: "0", isNight: true) == "moon.stars.fill")
    }

    @Test
    func formatterWindDirectionHandlesEdgeCasesAndNormalization() {
        let en = Locale(identifier: "en_US")
        let zh = Locale(identifier: "zh_Hans_CN")

        // 0° → North
        #expect(WeatherFormatter.windDirectionText(degrees: 0, locale: en).hasPrefix("N "))
        // 360° should normalise to 0° → North
        #expect(WeatherFormatter.windDirectionText(degrees: 360, locale: en).hasPrefix("N "))
        // 90° → East
        #expect(WeatherFormatter.windDirectionText(degrees: 90, locale: en).hasPrefix("E "))
        // 180° → South
        #expect(WeatherFormatter.windDirectionText(degrees: 180, locale: en).hasPrefix("S "))
        // 270° → West
        #expect(WeatherFormatter.windDirectionText(degrees: 270, locale: en).hasPrefix("W "))
        // Negative degrees should be normalised correctly — -90° ≡ 270° → West
        #expect(WeatherFormatter.windDirectionText(degrees: -90, locale: en).hasPrefix("W "))
        // Chinese locale
        #expect(WeatherFormatter.windDirectionText(degrees: 0, locale: zh).hasPrefix("北 "))
        #expect(WeatherFormatter.windDirectionText(degrees: 90, locale: zh).hasPrefix("东 "))
    }

    @Test
    func compositeCityGeocoderFallsBackToSecondaryOnPrimaryFailure() async throws {
        let primary = FailingCityGeocoder()
        let secondary = MockCityGeocoder(result: ("Shanghai", 31.2, 121.5, "Asia/Shanghai"))
        let composite = CompositeCityGeocoder(primary: primary, secondary: secondary)

        let result = try await composite.resolveCity("Shanghai")
        #expect(result.name == "Shanghai")
        #expect(result.lat == 31.2)
    }

    @Test
    func compositeCityGeocoderUsesPrimaryWhenAvailable() async throws {
        let primary = MockCityGeocoder(result: ("北京", 39.9, 116.4, "Asia/Shanghai"))
        let secondary = MockCityGeocoder(result: ("Fallback", 0, 0, "UTC"))
        let composite = CompositeCityGeocoder(primary: primary, secondary: secondary)

        let result = try await composite.resolveCity("北京")
        #expect(result.name == "北京")
    }

    @Test
    func compositeCityGeocoderWithNilPrimaryUsesSecondary() async throws {
        let secondary = MockCityGeocoder(result: ("Tokyo", 35.7, 139.7, "Asia/Tokyo"))
        let composite = CompositeCityGeocoder(primary: nil, secondary: secondary)

        let result = try await composite.resolveCity("Tokyo")
        #expect(result.name == "Tokyo")
    }

    @Test
    func repositoryFallsBackToStaleCacheOnProviderFailure() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let cache = SnapshotCacheStore(cacheDirectory: tempDir)
        let failingProvider = FailingWeatherProvider()
        let repo = WeatherRepository(provider: failingProvider, cacheStore: cache, ttl: 30 * 60, staleWindow: 3 * 60 * 60)

        let location = ResolvedLocation(name: "Test City", latitude: 1.0, longitude: 1.0, timezone: "UTC")
        let key = WeatherRepository.cacheKey(for: location)

        let snapshot = WeatherSnapshot(
            timestamp: Date(),
            timezone: "UTC",
            locationName: "Test City",
            values: [.temperature: 15],
            conditionCode: "1",
            sunrise: nil,
            sunset: nil,
            source: "Test"
        )
        let now = Date()
        // Store a snapshot that is 45 minutes old (stale but within 3-hour window)
        await cache.save(snapshot: snapshot, key: key, at: now.addingTimeInterval(-45 * 60))

        let result = try await repo.fetchSnapshot(for: location, now: now)
        #expect(result.freshness == .stale)
        #expect(result.snapshot.values[.temperature] == 15)
    }

    @Test
    func repositoryThrowsWhenNoProviderDataAndNoCache() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let cache = SnapshotCacheStore(cacheDirectory: tempDir)
        let failingProvider = FailingWeatherProvider()
        let repo = WeatherRepository(provider: failingProvider, cacheStore: cache)

        let location = ResolvedLocation(name: "Nowhere", latitude: 0, longitude: 0, timezone: "UTC")
        await #expect(throws: (any Error).self) {
            _ = try await repo.fetchSnapshot(for: location)
        }
    }
}

private struct MockWeatherProvider: WeatherProvider {
    let snapshot: WeatherSnapshot

    func fetchCurrent(lat: Double, lon: Double, tz: String) async throws -> WeatherSnapshot {
        snapshot
    }
}

private struct FailingWeatherProvider: WeatherProvider {
    func fetchCurrent(lat: Double, lon: Double, tz: String) async throws -> WeatherSnapshot {
        throw WeatherError.noValidData
    }
}

private struct MockCityGeocoder: CityGeocoder {
    let result: (name: String, lat: Double, lon: Double, tz: String)

    func resolveCity(_ name: String) async throws -> (name: String, lat: Double, lon: Double, tz: String) {
        _ = name
        return result
    }
}

private struct FailingCityGeocoder: CityGeocoder {
    func resolveCity(_ name: String) async throws -> (name: String, lat: Double, lon: Double, tz: String) {
        throw WeatherError.cityNotFound(name)
    }
}
