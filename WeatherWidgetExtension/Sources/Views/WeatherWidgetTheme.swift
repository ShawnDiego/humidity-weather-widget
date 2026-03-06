import SwiftUI
import WeatherCore
import WidgetKit

struct WeatherWidgetTheme {
    let category: WeatherConditionCategory
    let isNight: Bool

    var primaryText: Color { .white.opacity(0.96) }
    var secondaryText: Color { .white.opacity(isNight ? 0.80 : 0.82) }
    var tertiaryText: Color { .white.opacity(isNight ? 0.66 : 0.70) }
    var metricSecondaryText: Color { .white.opacity(isNight ? 0.70 : 0.74) }
    var staleText: Color { Color(red: 1.0, green: 0.77, blue: 0.42) }

    var backgroundGradient: [Color] {
        switch category {
        case .clear:
            return isNight
                ? [Color(red: 0.06, green: 0.14, blue: 0.30), Color(red: 0.12, green: 0.22, blue: 0.43)]
                : [Color(red: 0.26, green: 0.63, blue: 0.99), Color(red: 0.43, green: 0.80, blue: 1.00)]
        case .partlyCloudy:
            return isNight
                ? [Color(red: 0.11, green: 0.19, blue: 0.34), Color(red: 0.19, green: 0.29, blue: 0.45)]
                : [Color(red: 0.32, green: 0.58, blue: 0.90), Color(red: 0.62, green: 0.74, blue: 0.87)]
        case .mostlyCloudy:
            return [Color(red: 0.30, green: 0.41, blue: 0.55), Color(red: 0.43, green: 0.53, blue: 0.65)]
        case .overcast:
            return [Color(red: 0.27, green: 0.34, blue: 0.45), Color(red: 0.35, green: 0.43, blue: 0.55)]
        case .fog:
            return [Color(red: 0.38, green: 0.44, blue: 0.52), Color(red: 0.49, green: 0.56, blue: 0.63)]
        case .haze:
            return [Color(red: 0.47, green: 0.45, blue: 0.42), Color(red: 0.58, green: 0.55, blue: 0.49)]
        case .sandDust:
            return [Color(red: 0.53, green: 0.47, blue: 0.39), Color(red: 0.66, green: 0.58, blue: 0.47)]
        case .drizzle:
            return [Color(red: 0.20, green: 0.33, blue: 0.50), Color(red: 0.29, green: 0.44, blue: 0.61)]
        case .rain:
            return [Color(red: 0.16, green: 0.27, blue: 0.45), Color(red: 0.24, green: 0.38, blue: 0.56)]
        case .downpour:
            return [Color(red: 0.11, green: 0.20, blue: 0.36), Color(red: 0.16, green: 0.29, blue: 0.48)]
        case .sleet:
            return [Color(red: 0.32, green: 0.45, blue: 0.63), Color(red: 0.43, green: 0.58, blue: 0.74)]
        case .snow:
            return [Color(red: 0.44, green: 0.60, blue: 0.78), Color(red: 0.64, green: 0.79, blue: 0.91)]
        case .blizzard:
            return [Color(red: 0.29, green: 0.43, blue: 0.61), Color(red: 0.47, green: 0.63, blue: 0.79)]
        case .thunderstorm:
            return [Color(red: 0.11, green: 0.14, blue: 0.31), Color(red: 0.22, green: 0.21, blue: 0.48)]
        case .windy:
            return [Color(red: 0.20, green: 0.45, blue: 0.56), Color(red: 0.30, green: 0.59, blue: 0.67)]
        case .unknown:
            return [Color(red: 0.23, green: 0.30, blue: 0.42), Color(red: 0.33, green: 0.41, blue: 0.53)]
        }
    }

    var glowColor: Color? {
        switch category {
        case .clear:
            return (isNight ? Color(red: 0.54, green: 0.68, blue: 1.0) : Color(red: 1.0, green: 0.86, blue: 0.44)).opacity(isNight ? 0.18 : 0.24)
        case .partlyCloudy:
            return Color.white.opacity(isNight ? 0.11 : 0.16)
        case .thunderstorm:
            return Color(red: 0.67, green: 0.58, blue: 1.0).opacity(0.14)
        case .snow, .blizzard:
            return Color.white.opacity(0.10)
        default:
            return nil
        }
    }

    var scrimOpacity: Double {
        switch category {
        case .clear:
            return 0.08
        case .partlyCloudy:
            return 0.10
        case .mostlyCloudy:
            return 0.12
        case .overcast:
            return 0.14
        case .fog, .haze, .sandDust:
            return 0.15
        case .drizzle:
            return 0.14
        case .rain:
            return 0.16
        case .downpour, .thunderstorm:
            return 0.20
        case .sleet, .snow:
            return 0.14
        case .blizzard:
            return 0.18
        case .windy:
            return 0.12
        case .unknown:
            return 0.14
        }
    }

    var textureTint: Color {
        switch category {
        case .sandDust, .haze:
            return Color(red: 0.96, green: 0.85, blue: 0.65)
        default:
            return .white
        }
    }

    var conditionAccent: Color {
        switch category {
        case .clear:
            return isNight ? Color(red: 0.72, green: 0.82, blue: 1.0) : Color(red: 1.0, green: 0.84, blue: 0.33)
        case .partlyCloudy:
            return Color(red: 1.0, green: 0.76, blue: 0.42)
        case .mostlyCloudy, .overcast, .fog:
            return Color(red: 0.86, green: 0.90, blue: 0.96)
        case .haze:
            return Color(red: 0.92, green: 0.79, blue: 0.52)
        case .sandDust:
            return Color(red: 0.95, green: 0.74, blue: 0.46)
        case .drizzle, .rain, .downpour:
            return Color(red: 0.67, green: 0.85, blue: 1.0)
        case .sleet, .snow, .blizzard:
            return Color(red: 0.90, green: 0.95, blue: 1.0)
        case .thunderstorm:
            return Color(red: 0.78, green: 0.66, blue: 1.0)
        case .windy:
            return Color(red: 0.72, green: 0.97, blue: 0.90)
        case .unknown:
            return Color.white.opacity(0.86)
        }
    }

    var glyphPalette: WeatherGlyphPalette {
        switch category {
        case .clear:
            if isNight {
                return WeatherGlyphPalette(
                    primary: Color(red: 0.93, green: 0.95, blue: 1.00),
                    secondary: Color(red: 0.72, green: 0.82, blue: 1.00),
                    accent: Color(red: 0.85, green: 0.90, blue: 1.00),
                    stroke: Color.white.opacity(0.16)
                )
            }
            return WeatherGlyphPalette(
                primary: Color(red: 1.00, green: 0.89, blue: 0.45),
                secondary: Color(red: 1.00, green: 0.73, blue: 0.30),
                accent: Color(red: 1.00, green: 0.96, blue: 0.68),
                stroke: Color.white.opacity(0.12)
            )
        case .haze, .sandDust:
            return WeatherGlyphPalette(
                primary: Color(red: 0.97, green: 0.84, blue: 0.58),
                secondary: Color(red: 0.93, green: 0.75, blue: 0.47),
                accent: Color(red: 1.00, green: 0.92, blue: 0.75),
                stroke: Color.white.opacity(0.12)
            )
        case .thunderstorm:
            return WeatherGlyphPalette(
                primary: Color(red: 0.93, green: 0.95, blue: 1.00),
                secondary: Color(red: 0.72, green: 0.82, blue: 1.00),
                accent: Color(red: 1.00, green: 0.83, blue: 0.39),
                stroke: Color.white.opacity(0.18)
            )
        default:
            return WeatherGlyphPalette(
                primary: Color(red: 0.94, green: 0.97, blue: 1.00),
                secondary: Color(red: 0.71, green: 0.84, blue: 0.98),
                accent: conditionAccent,
                stroke: Color.white.opacity(0.15)
            )
        }
    }

    static func iconSize(for family: WidgetFamily) -> CGFloat {
        switch family {
        case .systemSmall:
            return 22
        case .systemMedium:
            return 26
        case .systemLarge:
            return 30
        default:
            return 26
        }
    }
}

struct WeatherGlyphPalette {
    let primary: Color
    let secondary: Color
    let accent: Color
    let stroke: Color
}
