import Foundation

public struct OpenMeteoProvider: WeatherProvider {
    private let network: NetworkClient

    public init(network: NetworkClient = URLSessionNetworkClient()) {
        self.network = network
    }

    public func fetchCurrent(lat: Double, lon: Double, tz: String) async throws -> WeatherSnapshot {
        let currentFields = [
            "temperature_2m",
            "relative_humidity_2m",
            "apparent_temperature",
            "precipitation_probability",
            "pressure_msl",
            "visibility",
            "wind_speed_10m",
            "wind_direction_10m",
            "weather_code",
            "shortwave_radiation"
        ].joined(separator: ",")

        let dailyFields = [
            "sunrise",
            "sunset",
            "daylight_duration",
            "uv_index_max"
        ].joined(separator: ",")

        let url = try URLRequestBuilder.makeURL(
            base: AppConfig.openMeteoBaseURL,
            path: "/forecast",
            queryItems: [
                URLQueryItem(name: "latitude", value: String(lat)),
                URLQueryItem(name: "longitude", value: String(lon)),
                URLQueryItem(name: "current", value: currentFields),
                URLQueryItem(name: "daily", value: dailyFields),
                URLQueryItem(name: "forecast_days", value: "1"),
                URLQueryItem(name: "timezone", value: tz)
            ]
        )

        let data = try await network.send(URLRequestBuilder.makeRequest(url: url), timeout: AppConfig.requestTimeout)
        let decoded = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)

        guard let current = decoded.current else {
            throw WeatherError.invalidResponse
        }

        var values: [WeatherMetric: Double] = [:]
        values[.temperature] = current.temperature2m
        values[.humidity] = current.relativeHumidity2m
        values[.feelsLike] = current.apparentTemperature
        values[.precipitationProbability] = current.precipitationProbability
        values[.pressure] = current.pressureMSL
        values[.visibility] = current.visibility.map { $0 / 1000.0 }
        values[.windSpeed] = current.windSpeed10m
        values[.windDirection] = current.windDirection10m
        values[.condition] = current.weatherCode.map(Double.init)
        values[.solarIrradiance] = current.shortwaveRadiation

        if let daylight = decoded.daily?.daylightDuration?.first {
            values[.daylightDuration] = daylight / 3600.0
        }
        if let uv = decoded.daily?.uvIndexMax?.first {
            values[.uvIndex] = uv
        }

        let sunrise = decoded.daily?.sunrise?.first.flatMap(DateParser.parseOpenMeteo(_:))
        let sunset = decoded.daily?.sunset?.first.flatMap(DateParser.parseOpenMeteo(_:))

        return WeatherSnapshot(
            timestamp: current.time.flatMap(DateParser.parseOpenMeteo(_:)) ?? Date(),
            timezone: decoded.timezone ?? tz,
            locationName: WeatherFormatter.localized("当前位置", "Current Location"),
            values: values.compactMapValues { $0 },
            conditionCode: current.weatherCode.map { String($0) } ?? "unknown",
            sunrise: sunrise,
            sunset: sunset,
            source: "Open-Meteo"
        )
    }
}

private struct OpenMeteoForecastResponse: Decodable {
    let timezone: String?
    let current: OpenMeteoCurrent?
    let daily: OpenMeteoDaily?
}

private struct OpenMeteoCurrent: Decodable {
    let time: String?
    let temperature2m: Double?
    let relativeHumidity2m: Double?
    let apparentTemperature: Double?
    let precipitationProbability: Double?
    let pressureMSL: Double?
    let visibility: Double?
    let windSpeed10m: Double?
    let windDirection10m: Double?
    let weatherCode: Int?
    let shortwaveRadiation: Double?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitationProbability = "precipitation_probability"
        case pressureMSL = "pressure_msl"
        case visibility
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
        case weatherCode = "weather_code"
        case shortwaveRadiation = "shortwave_radiation"
    }
}

private struct OpenMeteoDaily: Decodable {
    let sunrise: [String]?
    let sunset: [String]?
    let daylightDuration: [Double]?
    let uvIndexMax: [Double]?

    enum CodingKeys: String, CodingKey {
        case sunrise
        case sunset
        case daylightDuration = "daylight_duration"
        case uvIndexMax = "uv_index_max"
    }
}
