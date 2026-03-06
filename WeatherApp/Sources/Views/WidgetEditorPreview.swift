import SwiftUI
import WeatherCore
import WidgetKit

enum WidgetPreviewSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var widgetFamily: WidgetFamily {
        switch self {
        case .small:
            return .systemSmall
        case .medium:
            return .systemMedium
        case .large:
            return .systemLarge
        }
    }

    func label(prefersChinese: Bool) -> String {
        switch self {
        case .small:
            return prefersChinese ? "小号" : "Small"
        case .medium:
            return prefersChinese ? "中号" : "Medium"
        case .large:
            return prefersChinese ? "大号" : "Large"
        }
    }
}

enum WidgetPreviewWeather: String, CaseIterable, Identifiable {
    case clear
    case rain
    case downpour
    case snow
    case thunderstorm
    case haze

    var id: String { rawValue }

    var conditionCode: String {
        switch self {
        case .clear:
            return "100"
        case .rain:
            return "301"
        case .downpour:
            return "312"
        case .snow:
            return "400"
        case .thunderstorm:
            return "302"
        case .haze:
            return "502"
        }
    }

    func label(prefersChinese: Bool) -> String {
        switch self {
        case .clear:
            return prefersChinese ? "晴" : "Clear"
        case .rain:
            return prefersChinese ? "雨" : "Rain"
        case .downpour:
            return prefersChinese ? "大雨" : "Heavy Rain"
        case .snow:
            return prefersChinese ? "雪" : "Snow"
        case .thunderstorm:
            return prefersChinese ? "雷暴" : "Thunderstorm"
        case .haze:
            return prefersChinese ? "霾" : "Haze"
        }
    }
}

struct WidgetEditorPreview: View {
    let profile: DisplayProfile
    let locale: Locale
    let widgetFamily: WidgetFamily
    let conditionCode: String
    let isNight: Bool
    let locationName: String

    private let sampleValues: [WeatherMetric: Double] = [
        .temperature: 23,
        .humidity: 67,
        .solarIrradiance: 520,
        .daylightDuration: 11.6,
        .windSpeed: 18.2,
        .windDirection: 135,
        .feelsLike: 25,
        .pressure: 1006,
        .visibility: 8.4,
        .uvIndex: 5.3,
        .precipitationProbability: 64
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            WeatherWidgetBackground(category: conditionCategory, isNight: isNight)

            content
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(width: previewCanvasSize.width, height: previewCanvasSize.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
    }

    @ViewBuilder
    private var content: some View {
        switch widgetFamily {
        case .systemSmall:
            smallLayout
        case .systemMedium:
            mediumLayout
        case .systemLarge:
            largeLayout
        default:
            mediumLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                    Text(conditionText)
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                    Text(timestampText)
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                glyph
            }

            if let temperatureText {
                Text(temperatureText)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            metricListSection(columns: 1, maxCount: 2)
        }
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationName)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                    Text(conditionText)
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                    Text(timestampText)
                        .font(.caption2)
                        .foregroundStyle(theme.tertiaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 3) {
                    glyph
                    if let temperatureText {
                        Text(temperatureText)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }

            metricListSection(columns: 2, maxCount: 4)
        }
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationName)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                    Text(conditionText)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                    Text(timestampText)
                        .font(.caption)
                        .foregroundStyle(theme.tertiaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 3) {
                    glyph
                    if let temperatureText {
                        Text(temperatureText)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
            }

            metricListSection(columns: 2, maxCount: 8)
        }
    }

    @ViewBuilder
    private func metricListSection(columns: Int, maxCount: Int) -> some View {
        let filteredMetrics = profile.metrics.filter { $0 != .temperature && $0 != .condition }
        let metrics = Array(filteredMetrics.prefix(maxCount))
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: columns)

        if !metrics.isEmpty {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 6) {
                ForEach(metrics, id: \.self) { metric in
                    PreviewMetricCell(
                        metric: metric,
                        value: sampleValues[metric],
                        unitSystem: profile.unitSystem,
                        locale: locale,
                        secondaryTextColor: theme.metricSecondaryText,
                        primaryTextColor: theme.primaryText
                    )
                }
            }
        }
    }

    private var glyph: some View {
        WeatherGlyph(
            category: conditionCategory,
            isNight: isNight,
            size: WeatherWidgetTheme.iconSize(for: widgetFamily),
            palette: theme.glyphPalette
        )
        .shadow(color: .black.opacity(0.16), radius: 3, x: 0, y: 1)
    }

    private var previewCanvasSize: CGSize {
        switch widgetFamily {
        case .systemSmall:
            return CGSize(width: 154, height: 154)
        case .systemMedium:
            return CGSize(width: 320, height: 154)
        case .systemLarge:
            return CGSize(width: 320, height: 220)
        default:
            return CGSize(width: 320, height: 154)
        }
    }

    private var conditionCategory: WeatherConditionCategory {
        WeatherFormatter.weatherCategory(for: conditionCode)
    }

    private var theme: WeatherWidgetTheme {
        WeatherWidgetTheme(category: conditionCategory, isNight: isNight)
    }

    private var conditionText: String {
        WeatherFormatter.conditionDescription(for: conditionCode, locale: locale)
    }

    private var timestampText: String {
        Date().formatted(date: .omitted, time: .shortened)
    }

    private var temperatureText: String? {
        guard let temperature = sampleValues[.temperature] else {
            return nil
        }
        return WeatherFormatter.formattedValue(
            metric: .temperature,
            value: temperature,
            unitSystem: profile.unitSystem,
            locale: locale
        )
    }
}

private struct PreviewMetricCell: View {
    let metric: WeatherMetric
    let value: Double?
    let unitSystem: UnitSystem
    let locale: Locale
    let secondaryTextColor: Color
    let primaryTextColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: WeatherFormatter.metricSymbol(for: metric))
                    .font(.caption2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(secondaryTextColor)
                Text(WeatherFormatter.localizedMetricName(metric, locale: locale))
                    .font(.caption2)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
            }

            Text(displayText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displayText: String {
        guard let value else { return "--" }
        return WeatherFormatter.formattedValue(
            metric: metric,
            value: value,
            unitSystem: unitSystem,
            locale: locale
        )
    }
}
