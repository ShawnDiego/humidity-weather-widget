import Foundation

public struct WeatherSettings: Codable, Sendable, Hashable {
    public var qWeatherAPIKey: String
    public var debugShowDataSource: Bool

    public init(qWeatherAPIKey: String = "", debugShowDataSource: Bool = false) {
        self.qWeatherAPIKey = qWeatherAPIKey
        self.debugShowDataSource = debugShowDataSource
    }
}

public struct StoredLocation: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var name: String
    public var timezone: String
    public var updatedAt: Date

    public init(latitude: Double, longitude: Double, name: String, timezone: String, updatedAt: Date = Date()) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.timezone = timezone
        self.updatedAt = updatedAt
    }

    public var asResolvedLocation: ResolvedLocation {
        ResolvedLocation(name: name, latitude: latitude, longitude: longitude, timezone: timezone)
    }
}
