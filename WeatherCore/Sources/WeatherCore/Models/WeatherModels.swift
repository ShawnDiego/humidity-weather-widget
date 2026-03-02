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
        switch self {
        case .temperature: return "温度"
        case .humidity: return "湿度"
        case .condition: return "天气"
        case .solarIrradiance: return "太阳光照"
        case .daylightDuration: return "日照时长"
        case .windSpeed: return "风速"
        case .windDirection: return "风向"
        case .feelsLike: return "体感温度"
        case .pressure: return "气压"
        case .visibility: return "能见度"
        case .uvIndex: return "UV 指数"
        case .precipitationProbability: return "降水概率"
        }
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
            name: "默认方案",
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

    public init(
        timestamp: Date,
        timezone: String,
        locationName: String,
        values: [WeatherMetric: Double],
        conditionCode: String,
        sunrise: Date?,
        sunset: Date?,
        source: String
    ) {
        self.timestamp = timestamp
        self.timezone = timezone
        self.locationName = locationName
        self.values = values
        self.conditionCode = conditionCode
        self.sunrise = sunrise
        self.sunset = sunset
        self.source = source
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
        ResolvedLocation(name: "北京", latitude: 39.9042, longitude: 116.4074, timezone: "Asia/Shanghai")
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
