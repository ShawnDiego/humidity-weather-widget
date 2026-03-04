import Foundation

public enum WeatherError: LocalizedError, Sendable {
    case missingQWeatherAPIKey
    case invalidURL
    case invalidResponse
    case apiError(source: String, code: String, message: String)
    case cityNotFound(String)
    case locationUnavailable
    case emptyProfiles
    case noValidData
    case compositeFailure([Error])

    public var errorDescription: String? {
        switch self {
        case .missingQWeatherAPIKey:
            return loc("未配置和风天气 API Key。", "QWeather API key is not configured.")
        case .invalidURL:
            return loc("请求地址无效。", "The request URL is invalid.")
        case .invalidResponse:
            return loc("响应数据格式无效。", "The response format is invalid.")
        case let .apiError(source, code, message):
            return loc(
                "\(source) 请求失败（\(code)）：\(message)",
                "\(source) request failed (\(code)): \(message)"
            )
        case let .cityNotFound(city):
            return loc("未找到城市：\(city)", "City not found: \(city)")
        case .locationUnavailable:
            return loc("当前定位不可用。", "Current location is unavailable.")
        case .emptyProfiles:
            return loc("没有可用的显示方案。", "No display profile is available.")
        case .noValidData:
            return loc("没有可用天气数据。", "No valid weather data is available.")
        case let .compositeFailure(errors):
            let joined = errors.map { $0.localizedDescription }.joined(separator: loc("；", "; "))
            return loc("多源请求均失败：\(joined)", "All providers failed: \(joined)")
        }
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem() ? zh : en
    }
}
