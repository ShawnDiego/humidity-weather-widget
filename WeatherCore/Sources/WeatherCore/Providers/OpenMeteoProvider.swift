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

        let hourlyFields = [
            "temperature_2m",
            "relative_humidity_2m",
            "apparent_temperature",
            "precipitation_probability",
            "pressure_msl",
            "visibility",
            "wind_speed_10m",
            "wind_direction_10m",
            "uv_index",
            "weather_code"
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
                URLQueryItem(name: "hourly", value: hourlyFields),
                URLQueryItem(name: "daily", value: dailyFields),
                URLQueryItem(name: "forecast_days", value: "2"),
                URLQueryItem(name: "timezone", value: tz)
            ]
        )

        let data = try await network.send(URLRequestBuilder.makeRequest(url: url), timeout: AppConfig.requestTimeout)
        let decoded = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)

        guard let current = decoded.current else {
            throw WeatherError.invalidResponse
        }

        let resolvedTimezone = decoded.timezone ?? tz
        let currentTimestamp = current.time.flatMap {
            DateParser.parseOpenMeteo($0, timeZoneIdentifier: resolvedTimezone)
        } ?? Date()

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

        let sunrise = decoded.daily?.sunrise?.first.flatMap {
            DateParser.parseOpenMeteo($0, timeZoneIdentifier: resolvedTimezone)
        }
        let sunset = decoded.daily?.sunset?.first.flatMap {
            DateParser.parseOpenMeteo($0, timeZoneIdentifier: resolvedTimezone)
        }
        let hourly = makeHourlySeries(from: decoded.hourly, timezone: resolvedTimezone, currentTimestamp: currentTimestamp)

        return WeatherSnapshot(
            timestamp: currentTimestamp,
            timezone: resolvedTimezone,
            locationName: WeatherFormatter.localized("当前位置", "Current Location"),
            values: values.compactMapValues { $0 },
            conditionCode: current.weatherCode.map { String($0) } ?? "unknown",
            sunrise: sunrise,
            sunset: sunset,
            source: "开放气象",
            hourly: hourly
        )
    }

    private func makeHourlySeries(
        from hourly: OpenMeteoHourly?,
        timezone: String,
        currentTimestamp: Date
    ) -> [HourlyWeatherPoint] {
        guard let hourly,
              let times = hourly.time,
              !times.isEmpty
        else {
            return []
        }

        let cutoff = currentTimestamp.addingTimeInterval(-1800)
        var series: [HourlyWeatherPoint] = []
        series.reserveCapacity(min(24, times.count))

        for (index, rawTime) in times.enumerated() {
            guard let timestamp = DateParser.parseOpenMeteo(rawTime, timeZoneIdentifier: timezone) else {
                continue
            }
            if timestamp < cutoff { continue }

            var values: [WeatherMetric: Double] = [:]
            values[.temperature] = hourly.temperature2m?[safe: index]
            values[.humidity] = hourly.relativeHumidity2m?[safe: index]
            values[.feelsLike] = hourly.apparentTemperature?[safe: index]
            values[.precipitationProbability] = hourly.precipitationProbability?[safe: index]
            values[.pressure] = hourly.pressureMSL?[safe: index]
            values[.windSpeed] = hourly.windSpeed10m?[safe: index]
            values[.windDirection] = hourly.windDirection10m?[safe: index]
            values[.uvIndex] = hourly.uvIndex?[safe: index]

            if let visibility = hourly.visibility?[safe: index] {
                values[.visibility] = visibility / 1000.0
            }

            let weatherCode = hourly.weatherCode?[safe: index].map(String.init)
            if values.isEmpty && weatherCode == nil { continue }

            series.append(
                HourlyWeatherPoint(
                    timestamp: timestamp,
                    values: values.compactMapValues { $0 },
                    conditionCode: weatherCode
                )
            )

            if series.count >= 24 { break }
        }

        if !series.isEmpty {
            return series.sorted { $0.timestamp < $1.timestamp }
        }

        // If filtering by "current hour" removed everything, keep the first 24 parsed points as a fallback.
        for (index, rawTime) in times.enumerated() {
            guard series.count < 24,
                  let timestamp = DateParser.parseOpenMeteo(rawTime, timeZoneIdentifier: timezone)
            else {
                continue
            }

            var values: [WeatherMetric: Double] = [:]
            values[.temperature] = hourly.temperature2m?[safe: index]
            values[.humidity] = hourly.relativeHumidity2m?[safe: index]
            values[.feelsLike] = hourly.apparentTemperature?[safe: index]
            values[.precipitationProbability] = hourly.precipitationProbability?[safe: index]
            values[.pressure] = hourly.pressureMSL?[safe: index]
            values[.windSpeed] = hourly.windSpeed10m?[safe: index]
            values[.windDirection] = hourly.windDirection10m?[safe: index]
            values[.uvIndex] = hourly.uvIndex?[safe: index]

            if let visibility = hourly.visibility?[safe: index] {
                values[.visibility] = visibility / 1000.0
            }

            let weatherCode = hourly.weatherCode?[safe: index].map(String.init)
            if values.isEmpty && weatherCode == nil { continue }

            series.append(
                HourlyWeatherPoint(
                    timestamp: timestamp,
                    values: values.compactMapValues { $0 },
                    conditionCode: weatherCode
                )
            )
        }

        return series.sorted { $0.timestamp < $1.timestamp }
    }
}

private struct OpenMeteoForecastResponse: Decodable {
    let timezone: String?
    let current: OpenMeteoCurrent?
    let hourly: OpenMeteoHourly?
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

private struct OpenMeteoHourly: Decodable {
    let time: [String]?
    let temperature2m: [Double]?
    let relativeHumidity2m: [Double]?
    let apparentTemperature: [Double]?
    let precipitationProbability: [Double]?
    let pressureMSL: [Double]?
    let visibility: [Double]?
    let windSpeed10m: [Double]?
    let windDirection10m: [Double]?
    let uvIndex: [Double]?
    let weatherCode: [Int]?

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
        case uvIndex = "uv_index"
        case weatherCode = "weather_code"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
