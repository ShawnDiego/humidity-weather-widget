import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol NetworkClient: Sendable {
    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> Data
}

public struct URLSessionNetworkClient: NetworkClient {
    public init() {}

    public func send(_ request: URLRequest, timeout: TimeInterval = AppConfig.requestTimeout) async throws -> Data {
        var req = request
        req.timeoutInterval = timeout
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw WeatherError.invalidResponse
        }
        return data
    }
}
