import SwiftUI
import WidgetKit

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
        .configurationDisplayName("天气状态")
        .description("按你选择的字段显示当前天气")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
