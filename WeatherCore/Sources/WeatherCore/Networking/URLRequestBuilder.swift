import Foundation

enum URLRequestBuilder {
    static func makeURL(base: URL, path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
        guard let url = components?.url else { throw WeatherError.invalidURL }
        return url
    }

    static func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}
