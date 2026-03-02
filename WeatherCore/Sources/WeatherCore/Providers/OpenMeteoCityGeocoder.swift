import Foundation

public struct OpenMeteoCityGeocoder: CityGeocoder {
    private let network: NetworkClient

    public init(network: NetworkClient = URLSessionNetworkClient()) {
        self.network = network
    }

    public func resolveCity(_ name: String) async throws -> (name: String, lat: Double, lon: Double, tz: String) {
        let url = try URLRequestBuilder.makeURL(
            base: AppConfig.openMeteoGeoBaseURL,
            path: "/search",
            queryItems: [
                URLQueryItem(name: "name", value: name),
                URLQueryItem(name: "count", value: "1"),
                URLQueryItem(name: "language", value: "zh"),
                URLQueryItem(name: "format", value: "json")
            ]
        )

        let data = try await network.send(URLRequestBuilder.makeRequest(url: url), timeout: AppConfig.requestTimeout)
        let decoded = try JSONDecoder().decode(OpenMeteoGeocoderResponse.self, from: data)
        guard let result = decoded.results?.first else {
            throw WeatherError.cityNotFound(name)
        }

        return (
            name: result.name,
            lat: result.latitude,
            lon: result.longitude,
            tz: result.timezone ?? "Asia/Shanghai"
        )
    }
}

private struct OpenMeteoGeocoderResponse: Decodable {
    let results: [OpenMeteoGeocoderItem]?
}

private struct OpenMeteoGeocoderItem: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let timezone: String?
}
