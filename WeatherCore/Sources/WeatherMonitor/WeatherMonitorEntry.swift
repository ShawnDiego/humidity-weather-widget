// WeatherMonitor — headless CLI for cloud / server-side weather monitoring.
//
// Usage:
//   weather-monitor              # fetch once, print JSON, exit
//   weather-monitor --watch 1800 # fetch every 1800 s (minimum 60 s), print JSON
//
// Environment variables:
//   MONITOR_LOCATIONS  JSON array of {name, lat, lon, tz}
//                      Defaults to Beijing when absent.
//                      Example: '[{"name":"Tokyo","lat":35.6762,"lon":139.6503,"tz":"Asia/Tokyo"}]'
//   QWEATHER_KEY       和风天气 API key (optional; omit to use Open-Meteo only)
//   UNIT_SYSTEM        metric | imperial | auto  (default: metric)
//
// Output: one JSON object per fetch cycle written to stdout, errors to stderr.

import Foundation
import WeatherCore

// MARK: - Stderr helper

struct StandardError: TextOutputStream {
    mutating func write(_ string: String) {
        FileHandle.standardError.write(Data(string.utf8))
    }
}

// MARK: - Input types

struct MonitorLocation: Decodable, Sendable {
    let name: String
    let lat: Double
    let lon: Double
    let tz: String
}

// MARK: - Output types

struct MetricEntry: Encodable {
    let metric: String
    let label: String
    let value: String
    let rawValue: Double
}

struct LocationReport: Encodable {
    let location: String
    let timezone: String
    let fetchedAt: String
    let freshness: String
    let source: String
    let condition: String
    let metrics: [MetricEntry]
}

struct MonitorReport: Encodable {
    let reportedAt: String
    let locations: [LocationReport]
}

// MARK: - Helpers

func loadLocations() throws -> [MonitorLocation] {
    let json = ProcessInfo.processInfo.environment["MONITOR_LOCATIONS"] ?? ""
    guard !json.isEmpty else {
        return [MonitorLocation(name: "Beijing", lat: 39.9042, lon: 116.4074, tz: "Asia/Shanghai")]
    }
    return try JSONDecoder().decode([MonitorLocation].self, from: Data(json.utf8))
}

func makeRepository(qWeatherKey: String) -> WeatherRepository {
    let openMeteo = OpenMeteoProvider()
    let qWeather = qWeatherKey.isEmpty ? nil : QWeatherProvider(apiKey: qWeatherKey)
    let composite = CompositeWeatherProvider(primary: qWeather, secondary: openMeteo)
    return WeatherRepository(provider: composite)
}

// ISO8601DateFormatter is write-once at init and documented as thread-safe on
// Apple platforms. The same nonisolated(unsafe) pattern is used throughout
// WeatherCore (WeatherFormatter, QWeatherProvider) for identical reasons.
nonisolated(unsafe) let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

func buildReport(result: SnapshotResult, unitSystem: UnitSystem) -> LocationReport {
    let snapshot = result.snapshot
    let locale = Locale(identifier: "en_US_POSIX")

    var entries: [MetricEntry] = []
    for metric in WeatherMetric.allCases {
        guard let raw = snapshot.values[metric] else { continue }
        let formatted = WeatherFormatter.formattedValue(
            metric: metric,
            value: raw,
            unitSystem: unitSystem,
            locale: locale
        )
        entries.append(MetricEntry(
            metric: metric.rawValue,
            label: WeatherFormatter.localizedMetricName(metric, locale: locale),
            value: formatted,
            rawValue: raw
        ))
    }

    return LocationReport(
        location: snapshot.locationName,
        timezone: snapshot.timezone,
        fetchedAt: isoFormatter.string(from: snapshot.timestamp),
        freshness: result.freshness == .live ? "live" : "stale",
        source: snapshot.source,
        condition: WeatherFormatter.conditionDescription(for: snapshot.conditionCode, locale: locale),
        metrics: entries
    )
}

func fetchAndPrint(
    locations: [MonitorLocation],
    repository: WeatherRepository,
    unitSystem: UnitSystem
) async {
    var reports: [LocationReport] = []
    for loc in locations {
        let resolved = ResolvedLocation(
            name: loc.name,
            latitude: loc.lat,
            longitude: loc.lon,
            timezone: loc.tz
        )
        do {
            let result = try await repository.fetchSnapshot(for: resolved)
            reports.append(buildReport(result: result, unitSystem: unitSystem))
        } catch {
            var se = StandardError()
            print("[WeatherMonitor] fetch failed for \(loc.name): \(error)", to: &se)
        }
    }

    let report = MonitorReport(
        reportedAt: isoFormatter.string(from: Date()),
        locations: reports
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(report),
       let json = String(data: data, encoding: .utf8)
    {
        print(json)
    }
}

// MARK: - Entry point

@main
struct WeatherMonitorEntry {
    static func main() async {
        // Parse --watch <seconds>
        var watchIntervalSeconds: Int? = nil
        let args = Array(CommandLine.arguments.dropFirst())
        var idx = 0
        while idx < args.count {
            if args[idx] == "--watch", idx + 1 < args.count, let secs = Int(args[idx + 1]) {
                watchIntervalSeconds = max(60, secs)
                idx += 2
            } else {
                idx += 1
            }
        }

        // Bootstrap
        let qWeatherKey = ProcessInfo.processInfo.environment["QWEATHER_KEY"] ?? ""
        let unitSystemRaw = ProcessInfo.processInfo.environment["UNIT_SYSTEM"] ?? "metric"
        let unitSystem = UnitSystem(rawValue: unitSystemRaw) ?? .metric

        let locations: [MonitorLocation]
        do {
            locations = try loadLocations()
        } catch {
            var se = StandardError()
            print("[WeatherMonitor] MONITOR_LOCATIONS parse error: \(error)", to: &se)
            exit(1)
        }

        let repository = makeRepository(qWeatherKey: qWeatherKey)

        // Run
        if let interval = watchIntervalSeconds {
            while true {
                await fetchAndPrint(locations: locations, repository: repository, unitSystem: unitSystem)
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
            }
        } else {
            await fetchAndPrint(locations: locations, repository: repository, unitSystem: unitSystem)
        }
    }
}
