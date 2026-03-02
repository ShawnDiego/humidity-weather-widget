import Foundation

public struct QWeatherCityGeocoder: CityGeocoder {
    private let apiKey: String
    private let network: NetworkClient

    public init(apiKey: String, network: NetworkClient = URLSessionNetworkClient()) {
        self.apiKey = apiKey
        self.network = network
    }

    public func resolveCity(_ name: String) async throws -> (name: String, lat: Double, lon: Double, tz: String) {
        guard !apiKey.isEmpty else {
            throw WeatherError.missingQWeatherAPIKey
        }

        let url = try URLRequestBuilder.makeURL(
            base: AppConfig.qWeatherGeoBaseURL,
            path: "/city/lookup",
            queryItems: [
                URLQueryItem(name: "location", value: name),
                URLQueryItem(name: "key", value: apiKey)
            ]
        )

        let data = try await network.send(URLRequestBuilder.makeRequest(url: url), timeout: AppConfig.requestTimeout)
        let decoded = try JSONDecoder().decode(QWeatherCityResponse.self, from: data)
        guard decoded.code == "200", let city = decoded.location?.first else {
            throw WeatherError.cityNotFound(name)
        }

        guard let lat = Double(city.lat), let lon = Double(city.lon) else {
            throw WeatherError.invalidResponse
        }

        return (
            name: city.name,
            lat: lat,
            lon: lon,
            tz: city.tz ?? "Asia/Shanghai"
        )
    }
}

private struct QWeatherCityResponse: Decodable {
    let code: String
    let location: [QWeatherCity]?
}

private struct QWeatherCity: Decodable {
    let name: String
    let lat: String
    let lon: String
    let tz: String?
}
