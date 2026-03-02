import Foundation

public enum AppConfig {
    public static let appGroup = "group.com.diego.humidity"
    public static let qWeatherBaseURL = URL(string: "https://devapi.qweather.com/v7")!
    public static let qWeatherGeoBaseURL = URL(string: "https://geoapi.qweather.com/v2")!
    public static let openMeteoBaseURL = URL(string: "https://api.open-meteo.com/v1")!
    public static let openMeteoGeoBaseURL = URL(string: "https://geocoding-api.open-meteo.com/v1")!

    public static let cacheTTL: TimeInterval = 30 * 60
    public static let staleWindow: TimeInterval = 3 * 60 * 60

    public static let requestTimeout: TimeInterval = 4
    public static let maxConcurrentRequests = 2
}
