import SwiftUI
import WeatherCore
import WidgetKit

struct WeatherWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.locale) private var locale

    let entry: WeatherWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            metricGrid

            if entry.freshness == .stale {
                Text(localized("数据可能过期", "Data may be stale"))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if entry.showsSource {
                Text("\(localized("来源", "Source")): \(entry.snapshot.source)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(deepLinkURL)
        .containerBackground(.fill.tertiary, for: .widget)
        .dynamicTypeSize(.xSmall ... .large)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.locationName)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.snapshot.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(WeatherFormatter.conditionDescription(for: entry.snapshot.conditionCode, locale: locale))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: WeatherFormatter.weatherSymbol(for: entry.snapshot.conditionCode, isNight: isNight))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(conditionTint)
                    .font(.title3)
                    .symbolEffect(.pulse.byLayer, value: entry.snapshot.conditionCode)
                if let temperature = entry.snapshot.values[.temperature] {
                    Text(WeatherFormatter.formattedValue(
                        metric: .temperature,
                        value: temperature,
                        unitSystem: entry.profile.unitSystem,
                        locale: locale
                    ))
                        .font(.headline)
                        .contentTransition(.numericText())
                }
            }
        }
    }

    @ViewBuilder
    private var metricGrid: some View {
        let metrics = filteredMetrics.prefix(maxMetricCount)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: family == .systemSmall ? 1 : 2)

        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(Array(metrics), id: \.self) { metric in
                MetricCell(
                    metric: metric,
                    value: entry.snapshot.values[metric],
                    unitSystem: entry.profile.unitSystem,
                    locale: locale
                )
            }
        }
    }

    private var filteredMetrics: [WeatherMetric] {
        entry.profile.metrics.filter { $0 != .temperature }
    }

    private var maxMetricCount: Int {
        switch family {
        case .systemSmall:
            return 3
        case .systemMedium:
            return 6
        case .systemLarge:
            return 10
        default:
            return 6
        }
    }

    private var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "humidity"
        components.host = "weather"
        components.queryItems = [
            URLQueryItem(name: "profileId", value: entry.profile.id.uuidString),
            URLQueryItem(name: "location", value: entry.snapshot.locationName)
        ]
        return components.url
    }

    private var isNight: Bool {
        guard let sunrise = entry.snapshot.sunrise, let sunset = entry.snapshot.sunset else {
            return false
        }
        return entry.snapshot.timestamp < sunrise || entry.snapshot.timestamp >= sunset
    }

    private var conditionTint: Color {
        switch WeatherFormatter.weatherCategory(for: entry.snapshot.conditionCode) {
        case .clear:
            return .yellow
        case .partlyCloudy:
            return .orange
        case .cloudy:
            return .gray
        case .fog:
            return .gray.opacity(0.9)
        case .haze:
            return .brown
        case .rain:
            return .blue
        case .snow:
            return .cyan
        case .thunderstorm:
            return .indigo
        case .windy:
            return .mint
        case .unknown:
            return .secondary
        }
    }

    private func localized(_ zh: String, _ en: String) -> String {
        locale.language.languageCode?.identifier.hasPrefix("zh") == true ? zh : en
    }
}

private struct MetricCell: View {
    let metric: WeatherMetric
    let value: Double?
    let unitSystem: UnitSystem
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: WeatherFormatter.metricSymbol(for: metric))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(WeatherFormatter.localizedMetricName(metric, locale: locale))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(displayText)
                .font(.caption)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
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
