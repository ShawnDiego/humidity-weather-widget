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
    func snapshotMergeMergesHourlySeriesFromFallback() {
        let now = Date()
        var primary = WeatherSnapshot(
            timestamp: now,
            timezone: "Asia/Shanghai",
            locationName: "北京",
            values: [.temperature: 25],
            conditionCode: "100",
            sunrise: nil,
            sunset: nil,
            source: "Primary",
            hourly: [
                HourlyWeatherPoint(
                    timestamp: now,
                    values: [.temperature: 25]
                )
            ]
        )

        let fallback = WeatherSnapshot(
            timestamp: now,
            timezone: "Asia/Shanghai",
            locationName: "北京",
            values: [.humidity: 60],
            conditionCode: "101",
            sunrise: nil,
            sunset: nil,
            source: "Fallback",
            hourly: [
                HourlyWeatherPoint(
                    timestamp: now,
                    values: [.humidity: 60]
                ),
                HourlyWeatherPoint(
                    timestamp: now.addingTimeInterval(3600),
                    values: [.temperature: 24]
                )
            ]
        )

        primary.mergeMissingValues(from: fallback)

        #expect(primary.values[.humidity] == 60)
        #expect(primary.hourly.count == 2)
        #expect(primary.hourly.first?.values[.temperature] == 25)
        #expect(primary.hourly.first?.values[.humidity] == 60)
    }

    @Test
    func weatherSnapshotDecodesLegacyPayloadWithoutHourlySeries() throws {
        let payload = """
        {
          "timestamp": "2026-03-19T08:00:00Z",
          "timezone": "Asia/Shanghai",
          "locationName": "北京",
          "values": ["temperature", 22.5],
          "conditionCode": "100",
          "source": "Legacy"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(WeatherSnapshot.self, from: payload)

        #expect(snapshot.hourly.isEmpty)
        #expect(snapshot.values[.temperature] == 22.5)
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
        #expect(WeatherFormatter.localizedMetricName(.humidity, locale: us) == "湿度")
        #expect(WeatherFormatter.localizedMetricName(.humidity, locale: zh) == "湿度")
        #expect(WeatherFormatter.localizedUnitSystemName(.metric, locale: us).contains("公制"))
        #expect(WeatherFormatter.effectiveUnitSystem(.auto, locale: us) == .imperial)
        #expect(WeatherFormatter.effectiveUnitSystem(.auto, locale: zh) == .metric)
    }

    @Test
    func formatterSupportsHighGranularityWeatherMappings() {
        let qWeatherSamples: [(String, WeatherConditionCategory)] = [
            ("100", .clear),
            ("101", .partlyCloudy),
            ("102", .mostlyCloudy),
            ("104", .overcast),
            ("309", .drizzle),
            ("301", .rain),
            ("312", .downpour),
            ("404", .sleet),
            ("403", .blizzard),
            ("502", .haze),
            ("503", .sandDust),
            ("302", .thunderstorm),
            ("800", .windy)
        ]

        for (code, expected) in qWeatherSamples {
            #expect(WeatherFormatter.weatherCategory(for: code) == expected)
        }

        let wmoSamples: [(String, WeatherConditionCategory)] = [
            ("0", .clear),
            ("1", .partlyCloudy),
            ("2", .mostlyCloudy),
            ("3", .overcast),
            ("45", .fog),
            ("53", .drizzle),
            ("56", .sleet),
            ("63", .rain),
            ("65", .downpour),
            ("73", .snow),
            ("75", .blizzard),
            ("95", .thunderstorm)
        ]

        for (code, expected) in wmoSamples {
            #expect(WeatherFormatter.weatherCategory(for: code) == expected)
        }

        let fallbackSamples: [(String, WeatherConditionCategory)] = [
            ("1006", .mostlyCloudy),
            ("1009", .overcast),
            ("1150", .drizzle),
            ("1195", .downpour),
            ("1204", .sleet),
            ("1225", .blizzard),
            ("1276", .thunderstorm)
        ]

        for (code, expected) in fallbackSamples {
            #expect(WeatherFormatter.weatherCategory(for: code) == expected)
        }
    }

    @Test
    func formatterMapsConditionToLocalizedDescriptionAndSymbols() {
        let en = Locale(identifier: "en_US")
        let zh = Locale(identifier: "zh_Hans_CN")

        let localizedSamples: [(String, WeatherConditionCategory)] = [
            ("100", .clear),
            ("101", .partlyCloudy),
            ("102", .mostlyCloudy),
            ("104", .overcast),
            ("500", .fog),
            ("502", .haze),
            ("503", .sandDust),
            ("309", .drizzle),
            ("301", .rain),
            ("1195", .downpour),
            ("404", .sleet),
            ("1213", .snow),
            ("403", .blizzard),
            ("302", .thunderstorm),
            ("800", .windy)
        ]

        for (code, expectedCategory) in localizedSamples {
            #expect(WeatherFormatter.weatherCategory(for: code) == expectedCategory)
            #expect(WeatherFormatter.conditionDescription(for: code, locale: en) != "Unknown")
            #expect(WeatherFormatter.conditionDescription(for: code, locale: zh) != "未知")
        }

        #expect(WeatherFormatter.conditionDescription(for: "102", locale: en) == "大部多云")
        #expect(WeatherFormatter.conditionDescription(for: "404", locale: zh) == "雨夹雪")
        #expect(WeatherFormatter.weatherSymbol(for: "0", isNight: false) == "sun.max.fill")
        #expect(WeatherFormatter.weatherSymbol(for: "0", isNight: true) == "moon.stars.fill")
        #expect(WeatherFormatter.weatherSymbol(for: "404", isNight: false) == "cloud.sleet.fill")
        #expect(WeatherFormatter.weatherSymbol(for: "75", isNight: false) == "wind.snow")
    }
}

private struct MockWeatherProvider: WeatherProvider {
    let snapshot: WeatherSnapshot

    func fetchCurrent(lat: Double, lon: Double, tz: String) async throws -> WeatherSnapshot {
        snapshot
    }
}
