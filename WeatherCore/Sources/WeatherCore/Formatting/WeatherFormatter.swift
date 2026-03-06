import Foundation

public enum WeatherConditionCategory: Sendable {
    case clear
    case partlyCloudy
    case mostlyCloudy
    case overcast
    case fog
    case haze
    case sandDust
    case drizzle
    case rain
    case downpour
    case sleet
    case snow
    case blizzard
    case thunderstorm
    case windy
    case unknown
}

public enum WeatherFormatter {
    public static func prefersChinese(_ locale: Locale = .current) -> Bool {
        if locale.language.languageCode?.identifier.hasPrefix("zh") == true {
            return true
        }

        if locale.identifier.lowercased().hasPrefix("zh") {
            return true
        }
        return false
    }

    public static func localized(_ zh: String, _ en: String, locale: Locale = .current) -> String {
        zh
    }

    public static func prefersChineseSystem(_ locale: Locale = .current) -> Bool {
        true
    }

    public static func effectiveUnitSystem(_ unitSystem: UnitSystem, locale: Locale = .autoupdatingCurrent) -> UnitSystem {
        if unitSystem != .auto { return unitSystem }
        let measurementLocale = locale.region == nil ? Locale.autoupdatingCurrent : locale
        return measurementLocale.measurementSystem == .us ? .imperial : .metric
    }

    public static func localizedMetricName(_ metric: WeatherMetric, locale: Locale = .current) -> String {
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
        case .uvIndex: return "紫外线指数"
        case .precipitationProbability: return "降水概率"
        }
    }

    public static func localizedUnitSystemName(_ unitSystem: UnitSystem, locale: Locale = .current) -> String {
        let resolvedAuto = effectiveUnitSystem(.auto, locale: locale)

        switch unitSystem {
        case .auto:
            return resolvedAuto == .imperial ? "自动（按地区：英制）" : "自动（按地区：公制）"
        case .metric: return "公制（°C, km/h）"
        case .imperial: return "英制（°F, mph）"
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
        let directions = ["北", "东北", "东", "东南", "南", "西南", "西", "西北", "北"]
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
        case .mostlyCloudy:
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case .overcast:
            return "cloud.fill"
        case .fog:
            return "cloud.fog.fill"
        case .haze:
            return isNight ? "moon.haze.fill" : "sun.haze.fill"
        case .sandDust:
            return "sun.dust.fill"
        case .drizzle:
            return "cloud.drizzle.fill"
        case .rain:
            return "cloud.rain.fill"
        case .downpour:
            return "cloud.heavyrain.fill"
        case .sleet:
            return "cloud.sleet.fill"
        case .snow:
            return "cloud.snow.fill"
        case .blizzard:
            return "wind.snow"
        case .thunderstorm:
            return "cloud.bolt.rain.fill"
        case .windy:
            return "wind"
        case .unknown:
            return "cloud"
        }
    }

    public static func conditionDescription(for conditionCode: String, locale: Locale = .current) -> String {
        switch weatherCategory(for: conditionCode) {
        case .clear:
            return "晴朗"
        case .partlyCloudy:
            return "局部多云"
        case .mostlyCloudy:
            return "大部多云"
        case .overcast:
            return "阴天"
        case .fog:
            return "有雾"
        case .haze:
            return "霾"
        case .sandDust:
            return "浮尘"
        case .drizzle:
            return "毛毛雨"
        case .rain:
            return "降雨"
        case .downpour:
            return "强降雨"
        case .sleet:
            return "雨夹雪"
        case .snow:
            return "降雪"
        case .blizzard:
            return "暴风雪"
        case .thunderstorm:
            return "雷暴"
        case .windy:
            return "大风"
        case .unknown:
            return "未知"
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

        return weatherApiFallbackCategory(for: code)
    }

    private static func qWeatherCategory(for code: Int) -> WeatherConditionCategory {
        switch code {
        case 100, 150:
            return .clear
        case 101, 151:
            return .partlyCloudy
        case 102, 103, 152, 153:
            return .mostlyCloudy
        case 104, 154:
            return .overcast
        case 500, 501, 509, 510, 514, 515:
            return .fog
        case 502, 511, 512, 513:
            return .haze
        case 503, 504, 507, 508:
            return .sandDust
        case 300, 305, 309:
            return .drizzle
        case 301, 306, 313:
            return .rain
        case 307, 308, 310, 311, 312, 314, 315, 316, 317, 318:
            return .downpour
        case 302, 303, 304:
            return .thunderstorm
        case 404, 405:
            return .sleet
        case 402, 403, 410:
            return .blizzard
        case 400, 401, 406, 407, 408, 409:
            return .snow
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
        case 1:
            return .partlyCloudy
        case 2:
            return .mostlyCloudy
        case 3:
            return .overcast
        case 45, 48:
            return .fog
        case 51, 53, 55:
            return .drizzle
        case 56, 57, 66, 67:
            return .sleet
        case 61, 63, 80, 81:
            return .rain
        case 65, 82:
            return .downpour
        case 71, 73, 77, 85:
            return .snow
        case 75, 86:
            return .blizzard
        case 95 ... 99:
            return .thunderstorm
        default:
            return .unknown
        }
    }

    private static func weatherApiFallbackCategory(for code: Int) -> WeatherConditionCategory {
        switch code {
        case 1000:
            return .clear
        case 1003:
            return .partlyCloudy
        case 1006:
            return .mostlyCloudy
        case 1009:
            return .overcast
        case 1030, 1135, 1147:
            return .fog
        case 1063, 1150, 1153:
            return .drizzle
        case 1087, 1273, 1276:
            return .thunderstorm
        case 1066, 1210, 1213, 1216, 1219, 1222, 1255:
            return .snow
        case 1114, 1117, 1225, 1258, 1279, 1282:
            return .blizzard
        case 1069, 1072, 1168, 1171, 1198, 1201, 1204, 1207, 1237, 1249, 1252, 1261, 1264:
            return .sleet
        case 1180, 1183, 1186, 1189, 1240:
            return .rain
        case 1192, 1195, 1243, 1246:
            return .downpour
        default:
            return .unknown
        }
    }

    private static func format(_ value: Double, fractionDigits: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.*f", fractionDigits, value)
    }
}
