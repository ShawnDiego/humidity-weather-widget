import Foundation

public enum WeatherMetric: String, Codable, CaseIterable, Sendable {
    case temperature
    case humidity
    case condition
    case solarIrradiance
    case daylightDuration
    case windSpeed
    case windDirection
    case feelsLike
    case pressure
    case visibility
    case uvIndex
    case precipitationProbability

    public var displayName: String {
        let id = Locale.preferredLanguages.first ?? Locale.current.identifier
        return WeatherFormatter.localizedMetricName(self, locale: Locale(identifier: id))
    }
}

public enum UnitSystem: String, Codable, CaseIterable, Sendable {
    case auto
    case metric
    case imperial
}

public enum LocationMode: String, Codable, CaseIterable, Sendable {
    case current
    case manualCity
}

public struct DisplayProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var metrics: [WeatherMetric]
    public var unitSystem: UnitSystem

    public init(id: UUID = UUID(), name: String, metrics: [WeatherMetric], unitSystem: UnitSystem) {
        self.id = id
        self.name = name
        self.metrics = Self.deduplicated(metrics)
        self.unitSystem = unitSystem
    }

    public mutating func sanitizeMetrics() {
        metrics = Self.deduplicated(metrics)
    }

    private static func deduplicated(_ metrics: [WeatherMetric]) -> [WeatherMetric] {
        var seen = Set<WeatherMetric>()
        var result: [WeatherMetric] = []
        result.reserveCapacity(metrics.count)
        for metric in metrics where seen.insert(metric).inserted {
            result.append(metric)
        }
        return result
    }

    public static var `default`: DisplayProfile {
        DisplayProfile(
            name: WeatherFormatter.localized("默认方案", "Default Profile"),
            metrics: [.temperature, .humidity, .condition, .windSpeed, .windDirection, .daylightDuration],
            unitSystem: .auto
        )
    }
}

public struct WidgetInstanceConfig: Codable, Hashable, Sendable {
    public var profileId: UUID
    public var locationMode: LocationMode
    public var manualCityName: String?
    public var manualLatitude: Double?
    public var manualLongitude: Double?

    public init(
        profileId: UUID,
        locationMode: LocationMode,
        manualCityName: String? = nil,
        manualLatitude: Double? = nil,
        manualLongitude: Double? = nil
    ) {
        self.profileId = profileId
        self.locationMode = locationMode
        self.manualCityName = manualCityName
        self.manualLatitude = manualLatitude
        self.manualLongitude = manualLongitude
    }
}

public struct WeatherSnapshot: Codable, Hashable, Sendable {
    public var timestamp: Date
    public var timezone: String
    public var locationName: String
    public var values: [WeatherMetric: Double]
    public var conditionCode: String
    public var sunrise: Date?
    public var sunset: Date?
    public var source: String
    public var hourly: [HourlyWeatherPoint]

    public init(
        timestamp: Date,
        timezone: String,
        locationName: String,
        values: [WeatherMetric: Double],
        conditionCode: String,
        sunrise: Date?,
        sunset: Date?,
        source: String,
        hourly: [HourlyWeatherPoint] = []
    ) {
        self.timestamp = timestamp
        self.timezone = timezone
        self.locationName = locationName
        self.values = values
        self.conditionCode = conditionCode
        self.sunrise = sunrise
        self.sunset = sunset
        self.source = source
        self.hourly = hourly
    }

    public mutating func mergeMissingValues(from fallback: WeatherSnapshot) {
        for (metric, value) in fallback.values where values[metric] == nil {
            values[metric] = value
        }

        if sunrise == nil {
            sunrise = fallback.sunrise
        }
        if sunset == nil {
            sunset = fallback.sunset
        }

        mergeHourlySeries(from: fallback.hourly)
    }

    private mutating func mergeHourlySeries(from fallback: [HourlyWeatherPoint]) {
        guard !fallback.isEmpty else { return }

        if hourly.isEmpty {
            hourly = fallback
            return
        }

        var merged = Dictionary(uniqueKeysWithValues: hourly.map { ($0.timestamp, $0) })
        for point in fallback {
            if var existing = merged[point.timestamp] {
                existing.mergeMissingValues(from: point)
                merged[point.timestamp] = existing
            } else {
                merged[point.timestamp] = point
            }
        }
        hourly = merged.values.sorted { $0.timestamp < $1.timestamp }
    }

    enum CodingKeys: String, CodingKey {
        case timestamp
        case timezone
        case locationName
        case values
        case conditionCode
        case sunrise
        case sunset
        case source
        case hourly
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        timezone = try container.decode(String.self, forKey: .timezone)
        locationName = try container.decode(String.self, forKey: .locationName)
        values = try container.decode([WeatherMetric: Double].self, forKey: .values)
        conditionCode = try container.decode(String.self, forKey: .conditionCode)
        sunrise = try container.decodeIfPresent(Date.self, forKey: .sunrise)
        sunset = try container.decodeIfPresent(Date.self, forKey: .sunset)
        source = try container.decode(String.self, forKey: .source)
        hourly = try container.decodeIfPresent([HourlyWeatherPoint].self, forKey: .hourly) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(timezone, forKey: .timezone)
        try container.encode(locationName, forKey: .locationName)
        try container.encode(values, forKey: .values)
        try container.encode(conditionCode, forKey: .conditionCode)
        try container.encodeIfPresent(sunrise, forKey: .sunrise)
        try container.encodeIfPresent(sunset, forKey: .sunset)
        try container.encode(source, forKey: .source)
        try container.encode(hourly, forKey: .hourly)
    }
}

public struct HourlyWeatherPoint: Codable, Hashable, Sendable {
    public var timestamp: Date
    public var values: [WeatherMetric: Double]
    public var conditionCode: String?

    public init(timestamp: Date, values: [WeatherMetric: Double], conditionCode: String? = nil) {
        self.timestamp = timestamp
        self.values = values
        self.conditionCode = conditionCode
    }

    mutating func mergeMissingValues(from fallback: HourlyWeatherPoint) {
        for (metric, value) in fallback.values where values[metric] == nil {
            values[metric] = value
        }

        if conditionCode == nil {
            conditionCode = fallback.conditionCode
        }
    }
}

public struct ResolvedLocation: Codable, Hashable, Sendable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var timezone: String

    public init(name: String, latitude: Double, longitude: Double, timezone: String) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timezone = timezone
    }

    public static var beijingFallback: ResolvedLocation {
        ResolvedLocation(
            name: WeatherFormatter.localized("北京", "Beijing"),
            latitude: 39.9042,
            longitude: 116.4074,
            timezone: "Asia/Shanghai"
        )
    }
}

public enum SnapshotFreshness: Sendable {
    case live
    case stale
}

public struct SnapshotResult: Sendable {
    public var snapshot: WeatherSnapshot
    public var freshness: SnapshotFreshness

    public init(snapshot: WeatherSnapshot, freshness: SnapshotFreshness) {
        self.snapshot = snapshot
        self.freshness = freshness
    }
}

public protocol WeatherProvider: Sendable {
    func fetchCurrent(lat: Double, lon: Double, tz: String) async throws -> WeatherSnapshot
}

public protocol CityGeocoder: Sendable {
    func resolveCity(_ name: String) async throws -> (name: String, lat: Double, lon: Double, tz: String)
}
