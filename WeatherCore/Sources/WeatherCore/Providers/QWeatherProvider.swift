import Foundation

public struct QWeatherProvider: WeatherProvider {
    private let apiKey: String
    private let network: NetworkClient

    public init(apiKey: String, network: NetworkClient = URLSessionNetworkClient()) {
        self.apiKey = apiKey
        self.network = network
    }

    public func fetchCurrent(lat: Double, lon: Double, tz: String) async throws -> WeatherSnapshot {
        guard !apiKey.isEmpty else {
            throw WeatherError.missingQWeatherAPIKey
        }

        async let nowResponse = fetchNow(lat: lat, lon: lon)
        async let sunResponse = fetchSun(lat: lat, lon: lon)

        let now = try await nowResponse
        let sun = try? await sunResponse

        var values: [WeatherMetric: Double] = [:]
        values[.temperature] = Double(now.temp)
        values[.humidity] = Double(now.humidity)
        values[.condition] = Double(now.icon)
        values[.windSpeed] = Double(now.windSpeed)
        values[.windDirection] = Double(now.wind360)
        values[.feelsLike] = Double(now.feelsLike)
        values[.pressure] = Double(now.pressure)
        values[.visibility] = Double(now.vis)

        let timeZone = TimeZone(identifier: tz) ?? .current
        let sunrise = sun?.sunrise.flatMap { parseClockTime($0, timeZone: timeZone) }
        let sunset = sun?.sunset.flatMap { parseClockTime($0, timeZone: timeZone) }

        if let sunrise, let sunset {
            let daylightHours = max(0, sunset.timeIntervalSince(sunrise) / 3600)
            values[.daylightDuration] = daylightHours
        }

        return WeatherSnapshot(
            timestamp: ISO8601DateFormatter().date(from: now.obsTime) ?? Date(),
            timezone: tz,
            locationName: WeatherFormatter.localized("当前位置", "Current Location"),
            values: values,
            conditionCode: now.icon,
            sunrise: sunrise,
            sunset: sunset,
            source: "QWeather"
        )
    }

    private func fetchNow(lat: Double, lon: Double) async throws -> QWeatherNow {
        let url = try URLRequestBuilder.makeURL(
            base: AppConfig.qWeatherBaseURL,
            path: "/weather/now",
            queryItems: [
                URLQueryItem(name: "location", value: "\(lon),\(lat)"),
                URLQueryItem(name: "key", value: apiKey)
            ]
        )

        let data = try await network.send(URLRequestBuilder.makeRequest(url: url), timeout: AppConfig.requestTimeout)
        let decoded = try JSONDecoder().decode(QWeatherNowResponse.self, from: data)
        guard decoded.code == "200", let now = decoded.now else {
            throw WeatherError.apiError(
                source: "QWeather",
                code: decoded.code,
                message: WeatherFormatter.localized("天气接口返回失败", "Current weather request failed")
            )
        }
        return now
    }

    private func fetchSun(lat: Double, lon: Double) async throws -> QWeatherSun {
        let date = DateFormatter.yyyyMMdd.string(from: Date())
        let url = try URLRequestBuilder.makeURL(
            base: AppConfig.qWeatherBaseURL,
            path: "/astronomy/sun",
            queryItems: [
                URLQueryItem(name: "location", value: "\(lon),\(lat)"),
                URLQueryItem(name: "date", value: date),
                URLQueryItem(name: "key", value: apiKey)
            ]
        )

        let data = try await network.send(URLRequestBuilder.makeRequest(url: url), timeout: AppConfig.requestTimeout)
        let decoded = try JSONDecoder().decode(QWeatherSunResponse.self, from: data)
        guard decoded.code == "200" else {
            throw WeatherError.apiError(
                source: "QWeather",
                code: decoded.code,
                message: WeatherFormatter.localized("日出日落接口返回失败", "Sunrise/Sunset request failed")
            )
        }
        return decoded
    }

    private func parseClockTime(_ timeString: String, timeZone: TimeZone) -> Date? {
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1])
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }
}

private struct QWeatherNowResponse: Decodable {
    let code: String
    let now: QWeatherNow?
}

private struct QWeatherNow: Decodable {
    let obsTime: String
    let temp: String
    let feelsLike: String
    let icon: String
    let humidity: String
    let pressure: String
    let vis: String
    let windSpeed: String
    let wind360: String
}

private struct QWeatherSunResponse: Decodable {
    let code: String
    let sunrise: String?
    let sunset: String?
}

private typealias QWeatherSun = QWeatherSunResponse

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
