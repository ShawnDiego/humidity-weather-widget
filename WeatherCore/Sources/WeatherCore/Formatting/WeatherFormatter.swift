import Foundation

public enum WeatherConditionCategory: Sendable {
    case clear
    case partlyCloudy
    case cloudy
    case fog
    case haze
    case rain
    case snow
    case thunderstorm
    case windy
    case unknown
}

public enum WeatherFormatter {
    public static func effectiveUnitSystem(_ unitSystem: UnitSystem, locale: Locale = .current) -> UnitSystem {
        if unitSystem != .auto { return unitSystem }
        if locale.region?.identifier == "US" {
            return .imperial
        }
        return .metric
    }

    public static func localizedMetricName(_ metric: WeatherMetric, locale: Locale = .current) -> String {
        if isChineseLocale(locale) {
            switch metric {
            case .temperature: return "温度"
            case .humidity: return "湿度"
            case .condition: return "天气"
            case .solarIrradiance: return "太阳光照"
            case .daylightDuration: return "日照时长"
            case .windSpeed: return "风速"
            case .windDirection: return "风向"
            case .feelsLike: return "体感温度"
            case .pressure: return "气压"
            case .visibility: return "能见度"
            case .uvIndex: return "UV 指数"
            case .precipitationProbability: return "降水概率"
            }
        }

        switch metric {
        case .temperature: return "Temperature"
        case .humidity: return "Humidity"
        case .condition: return "Condition"
        case .solarIrradiance: return "Solar Irradiance"
        case .daylightDuration: return "Daylight"
        case .windSpeed: return "Wind Speed"
        case .windDirection: return "Wind Direction"
        case .feelsLike: return "Feels Like"
        case .pressure: return "Pressure"
        case .visibility: return "Visibility"
        case .uvIndex: return "UV Index"
        case .precipitationProbability: return "Precip. Chance"
        }
    }

    public static func localizedUnitSystemName(_ unitSystem: UnitSystem, locale: Locale = .current) -> String {
        if isChineseLocale(locale) {
            switch unitSystem {
            case .auto: return "自动（按地区）"
            case .metric: return "公制（°C, km/h）"
            case .imperial: return "英制（°F, mph）"
            }
        }

        switch unitSystem {
        case .auto: return "Automatic (Region)"
        case .metric: return "Metric (°C, km/h)"
        case .imperial: return "Imperial (°F, mph)"
        }
    }

    public static func formattedValue(
        metric: WeatherMetric,
        value: Double,
        unitSystem: UnitSystem,
        locale: Locale = .current
    ) -> String {
        let resolved = effectiveUnitSystem(unitSystem, locale: locale)

        switch metric {
        case .temperature, .feelsLike:
            let temp = resolved == .imperial ? value * 9 / 5 + 32 : value
            return "\(format(temp, fractionDigits: 1, locale: locale))°\(resolved == .imperial ? "F" : "C")"
        case .humidity, .precipitationProbability:
            return "\(format(value, fractionDigits: 0, locale: locale))%"
        case .windSpeed:
            let speed = resolved == .imperial ? value * 0.621371 : value
            return "\(format(speed, fractionDigits: 1, locale: locale)) \(resolved == .imperial ? "mph" : "km/h")"
        case .windDirection:
            return windDirectionText(degrees: value, locale: locale)
        case .pressure:
            let pressure = resolved == .imperial ? value * 0.029529983071445 : value
            return "\(format(pressure, fractionDigits: resolved == .imperial ? 2 : 0, locale: locale)) \(resolved == .imperial ? "inHg" : "hPa")"
        case .visibility:
            let vis = resolved == .imperial ? value * 0.621371 : value
            return "\(format(vis, fractionDigits: 1, locale: locale)) \(resolved == .imperial ? "mi" : "km")"
        case .solarIrradiance:
            return "\(format(value, fractionDigits: 0, locale: locale)) W/m²"
        case .daylightDuration:
            return "\(format(value, fractionDigits: 1, locale: locale)) h"
        case .uvIndex:
            return format(value, fractionDigits: 1, locale: locale)
        case .condition:
            return conditionDescription(for: String(Int(value)), locale: locale)
        }
    }

    public static func metricSymbol(for metric: WeatherMetric) -> String {
        switch metric {
        case .temperature: return "thermometer.sun.fill"
        case .humidity: return "humidity.fill"
        case .condition: return "cloud.fill"
        case .solarIrradiance: return "sun.max.fill"
        case .daylightDuration: return "sunrise.fill"
        case .windSpeed: return "wind"
        case .windDirection: return "location.north.line.fill"
        case .feelsLike: return "thermometer.medium"
        case .pressure: return "gauge.with.dots.needle.33percent"
        case .visibility: return "eye.fill"
        case .uvIndex: return "sun.max.trianglebadge.exclamationmark.fill"
        case .precipitationProbability: return "umbrella.percent.fill"
        }
    }

    public static func windDirectionText(degrees: Double, locale: Locale = .current) -> String {
        let normalized = ((degrees.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let directions: [String]
        if isChineseLocale(locale) {
            directions = ["北", "东北", "东", "东南", "南", "西南", "西", "西北", "北"]
        } else {
            directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        }
        let index = Int((normalized + 22.5) / 45.0)
        let direction = directions[max(0, min(index, directions.count - 1))]
        return "\(direction) \(format(normalized, fractionDigits: 0, locale: locale))°"
    }

    public static func weatherSymbol(for conditionCode: String, isNight: Bool = false) -> String {
        switch weatherCategory(for: conditionCode) {
        case .clear:
            return isNight ? "moon.stars.fill" : "sun.max.fill"
        case .partlyCloudy:
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case .cloudy:
            return "cloud.fill"
        case .fog:
            return "cloud.fog.fill"
        case .haze:
            return isNight ? "moon.haze.fill" : "sun.haze.fill"
        case .rain:
            return "cloud.rain.fill"
        case .snow:
            return "cloud.snow.fill"
        case .thunderstorm:
            return "cloud.bolt.rain.fill"
        case .windy:
            return "wind"
        case .unknown:
            return "cloud"
        }
    }

    public static func conditionDescription(for conditionCode: String, locale: Locale = .current) -> String {
        let chinese = isChineseLocale(locale)
        switch weatherCategory(for: conditionCode) {
        case .clear:
            return chinese ? "晴朗" : "Clear"
        case .partlyCloudy:
            return chinese ? "局部多云" : "Partly Cloudy"
        case .cloudy:
            return chinese ? "多云" : "Cloudy"
        case .fog:
            return chinese ? "有雾" : "Foggy"
        case .haze:
            return chinese ? "霾" : "Hazy"
        case .rain:
            return chinese ? "降雨" : "Rain"
        case .snow:
            return chinese ? "降雪" : "Snow"
        case .thunderstorm:
            return chinese ? "雷暴" : "Thunderstorm"
        case .windy:
            return chinese ? "大风" : "Windy"
        case .unknown:
            return chinese ? "未知" : "Unknown"
        }
    }

    public static func weatherCategory(for conditionCode: String) -> WeatherConditionCategory {
        guard let code = Int(conditionCode) else {
            return .unknown
        }

        if (100 ... 999).contains(code) {
            return qWeatherCategory(for: code)
        }
        if (0 ... 99).contains(code) {
            return wmoCategory(for: code)
        }

        switch code {
        case 1000 ... 1003:
            return .clear
        case 1004 ... 1006:
            return .partlyCloudy
        case 1007 ... 1030:
            return .cloudy
        case 1063 ... 1201:
            return .rain
        case 1204 ... 1237:
            return .snow
        case 1273 ... 1282:
            return .thunderstorm
        default:
            return .unknown
        }
    }

    private static func qWeatherCategory(for code: Int) -> WeatherConditionCategory {
        switch code {
        case 100, 150:
            return .clear
        case 101, 102, 103, 151, 152, 153:
            return .partlyCloudy
        case 104, 154:
            return .cloudy
        case 302 ... 304:
            return .thunderstorm
        case 300 ... 399:
            return .rain
        case 400 ... 499:
            return .snow
        case 500, 501, 509, 510, 514, 515:
            return .fog
        case 502 ... 508, 511 ... 513:
            return .haze
        case 800 ... 899:
            return .windy
        default:
            return .unknown
        }
    }

    private static func wmoCategory(for code: Int) -> WeatherConditionCategory {
        switch code {
        case 0:
            return .clear
        case 1, 2:
            return .partlyCloudy
        case 3:
            return .cloudy
        case 45, 48:
            return .fog
        case 51 ... 67, 80 ... 82:
            return .rain
        case 71 ... 77, 85, 86:
            return .snow
        case 95 ... 99:
            return .thunderstorm
        default:
            return .unknown
        }
    }

    private static func isChineseLocale(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier.hasPrefix("zh") == true
    }

    private static let numberFormatterCache: NSCache<NSString, NumberFormatter> = {
        let cache = NSCache<NSString, NumberFormatter>()
        cache.countLimit = 20
        return cache
    }()

    private static func format(_ value: Double, fractionDigits: Int, locale: Locale) -> String {
        let key = NSString(string: "\(locale.identifier)/\(fractionDigits)")
        let formatter: NumberFormatter
        if let cached = numberFormatterCache.object(forKey: key) {
            formatter = cached
        } else {
            let newFormatter = NumberFormatter()
            newFormatter.locale = locale
            newFormatter.numberStyle = .decimal
            newFormatter.minimumFractionDigits = 0
            newFormatter.maximumFractionDigits = fractionDigits
            numberFormatterCache.setObject(newFormatter, forKey: key)
            formatter = newFormatter
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.*f", fractionDigits, value)
    }
}
