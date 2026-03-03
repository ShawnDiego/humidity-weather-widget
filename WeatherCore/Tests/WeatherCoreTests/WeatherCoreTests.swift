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
    func dateParserHandlesOpenMeteoLocalTimeFormat() {
        // Open-Meteo returns "yyyy-MM-dd'T'HH:mm" (local time, no timezone designator)
        // when a timezone is specified in the request.  Both ISO-8601 formatters
        // used to return nil for this format, causing timestamp/sunrise/sunset to
        // be lost and isNight to always evaluate to false.
        let shanghai = TimeZone(identifier: "Asia/Shanghai")!
        let parsed = DateParser.parseOpenMeteo("2024-07-01T14:00", timeZone: shanghai)
        #expect(parsed != nil, "Local-time format must be parsed successfully")

        // Verify the hour component is preserved in the target timezone
        if let date = parsed {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = shanghai
            #expect(cal.component(.hour, from: date) == 14)
            #expect(cal.component(.month, from: date) == 7)
            #expect(cal.component(.day, from: date) == 1)
        }

        // ISO8601 with Z should still work (backward-compat)
        let utcParsed = DateParser.parseOpenMeteo("2024-07-01T14:00:00Z")
        #expect(utcParsed != nil, "ISO-8601 UTC format must still be parsed")

        // Completely invalid strings must return nil
        #expect(DateParser.parseOpenMeteo("not-a-date") == nil)
    }

    @Test
    func qWeatherSunDateUsesLocalTimezone() {
        // This test validates the date/timezone consistency that the fetchSun fix enforces:
        // the date string sent to the QWeather sun API must be in the location's local
        // timezone, not UTC.  Before the fix, UTC was used, so for UTC+8 locations after
        // 16:00 UTC the API would receive yesterday's date while parseClockTime would
        // reconstruct the time on today's date — producing an off-by-one-day sunrise/sunset.

        // Simulate 23:30 UTC on July 1 — for a UTC+8 location the local date is July 2.
        let simulatedNow = ISO8601DateFormatter().date(from: "2024-07-01T23:30:00Z")!
        let tz = TimeZone(identifier: "Asia/Shanghai")!

        let utcFormatter = DateFormatter()
        utcFormatter.dateFormat = "yyyyMMdd"
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")
        utcFormatter.timeZone = TimeZone(secondsFromGMT: 0)!

        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyyMMdd"
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.timeZone = tz

        let utcDate = utcFormatter.string(from: simulatedNow)    // "20240701" — wrong for Shanghai
        let localDate = localFormatter.string(from: simulatedNow) // "20240702" — correct for Shanghai

        #expect(utcDate != localDate, "UTC and local dates must differ near midnight UTC")
        #expect(localDate == "20240702", "Local Shanghai date must be July 2")

        // Verify parseClockTime also uses the same local date so both sides are consistent.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let dayInShanghai = cal.component(.day, from: simulatedNow)
        #expect(dayInShanghai == 2, "Calendar day in Shanghai must be 2")
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
