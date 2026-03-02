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
}

private struct MockWeatherProvider: WeatherProvider {
    let snapshot: WeatherSnapshot

    func fetchCurrent(lat: Double, lon: Double, tz: String) async throws -> WeatherSnapshot {
        snapshot
    }
}
