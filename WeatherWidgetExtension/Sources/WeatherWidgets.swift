import SwiftUI
import WidgetKit
import WeatherCore

@main
struct WeatherWidgets: WidgetBundle {
    var body: some Widget {
        CurrentWeatherWidget()
    }
}

struct CurrentWeatherWidget: Widget {
    let kind = "CurrentWeatherWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WeatherWidgetConfigurationIntent.self, provider: WeatherTimelineProvider()) { entry in
            WeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(LocalizedStringKey(loc("天气状态", "Weather Status")))
        .description(LocalizedStringKey(loc("按你选择的字段显示当前天气", "Show current weather with selected metrics")))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem() ? zh : en
    }
}
