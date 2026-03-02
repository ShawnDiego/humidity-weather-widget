import SwiftUI
import WeatherCore
import WidgetKit

struct WeatherWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: WeatherWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            metricGrid

            if entry.freshness == .stale {
                Text("数据可能过期")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if entry.showsSource {
                Text("来源：\(entry.snapshot.source)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(deepLinkURL)
        .containerBackground(.fill.tertiary, for: .widget)
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
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: WeatherFormatter.weatherSymbol(for: entry.snapshot.conditionCode))
                    .symbolRenderingMode(.multicolor)
                    .font(.title3)
                if let temperature = entry.snapshot.values[.temperature] {
                    Text(WeatherFormatter.formattedValue(metric: .temperature, value: temperature, unitSystem: entry.profile.unitSystem))
                        .font(.headline)
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
                MetricCell(metric: metric, value: entry.snapshot.values[metric], unitSystem: entry.profile.unitSystem)
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
}

private struct MetricCell: View {
    let metric: WeatherMetric
    let value: Double?
    let unitSystem: UnitSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(displayText)
                .font(.caption)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private var displayText: String {
        guard let value else { return "--" }
        return WeatherFormatter.formattedValue(metric: metric, value: value, unitSystem: unitSystem)
    }
}
