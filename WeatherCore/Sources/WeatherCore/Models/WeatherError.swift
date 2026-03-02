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
            return "未配置和风天气 API Key。"
        case .invalidURL:
            return "请求地址无效。"
        case .invalidResponse:
            return "响应数据格式无效。"
        case let .apiError(source, code, message):
            return "\(source) 请求失败（\(code)）：\(message)"
        case let .cityNotFound(city):
            return "未找到城市：\(city)"
        case .locationUnavailable:
            return "当前定位不可用。"
        case .emptyProfiles:
            return "没有可用的显示方案。"
        case .noValidData:
            return "没有可用天气数据。"
        case let .compositeFailure(errors):
            let joined = errors.map { $0.localizedDescription }.joined(separator: "；")
            return "多源请求均失败：\(joined)"
        }
    }
}
