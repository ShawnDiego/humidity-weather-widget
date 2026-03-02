import Foundation

public enum WeatherFormatter {
    public static func effectiveUnitSystem(_ unitSystem: UnitSystem, locale: Locale = .current) -> UnitSystem {
        if unitSystem != .auto { return unitSystem }
        if locale.region?.identifier == "US" {
            return .imperial
        }
        return .metric
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
            return "\(format(temp, fractionDigits: 1))°\(resolved == .imperial ? "F" : "C")"
        case .humidity, .precipitationProbability:
            return "\(format(value, fractionDigits: 0))%"
        case .windSpeed:
            let speed = resolved == .imperial ? value * 0.621371 : value
            return "\(format(speed, fractionDigits: 1)) \(resolved == .imperial ? "mph" : "km/h")"
        case .windDirection:
            return windDirectionText(degrees: value)
        case .pressure:
            let pressure = resolved == .imperial ? value * 0.029529983071445 : value
            return "\(format(pressure, fractionDigits: resolved == .imperial ? 2 : 0)) \(resolved == .imperial ? "inHg" : "hPa")"
        case .visibility:
            let vis = resolved == .imperial ? value * 0.621371 : value
            return "\(format(vis, fractionDigits: 1)) \(resolved == .imperial ? "mi" : "km")"
        case .solarIrradiance:
            return "\(format(value, fractionDigits: 0)) W/m²"
        case .daylightDuration:
            return "\(format(value, fractionDigits: 1)) h"
        case .uvIndex:
            return format(value, fractionDigits: 1)
        case .condition:
            return String(Int(value))
        }
    }

    public static func windDirectionText(degrees: Double) -> String {
        let normalized = ((degrees.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
        let index = Int((normalized + 22.5) / 45.0)
        let direction = directions[max(0, min(index, directions.count - 1))]
        return "\(direction) \(format(normalized, fractionDigits: 0))°"
    }

    public static func weatherSymbol(for conditionCode: String) -> String {
        guard let code = Int(conditionCode) else { return "cloud" }
        switch code {
        case 1000 ... 1003, 0 ... 1: return "sun.max.fill"
        case 1004 ... 1006, 2 ... 3: return "cloud.sun.fill"
        case 1007 ... 1030, 45 ... 48: return "cloud.fill"
        case 1063 ... 1201, 51 ... 67: return "cloud.rain.fill"
        case 1204 ... 1237, 71 ... 77: return "cloud.snow.fill"
        case 1273 ... 1282, 95 ... 99: return "cloud.bolt.rain.fill"
        default: return "cloud"
        }
    }

    private static func format(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.*f", fractionDigits, value)
    }
}
