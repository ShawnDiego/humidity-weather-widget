import Foundation
import WeatherCore
import WidgetKit

struct WeatherWidgetEntry: TimelineEntry {
    let date: Date
    let profile: DisplayProfile
    let snapshot: WeatherSnapshot
    let freshness: SnapshotFreshness
    let configIntent: WeatherWidgetConfigurationIntent
    let showsSource: Bool

    static var placeholder: WeatherWidgetEntry {
        let snapshot = WeatherSnapshot(
            timestamp: Date(),
            timezone: "Asia/Shanghai",
            locationName: WeatherFormatter.localized("北京", "Beijing"),
            values: [
                .temperature: 22,
                .humidity: 55,
                .windSpeed: 12,
                .windDirection: 180,
                .daylightDuration: 12
            ],
            conditionCode: "100",
            sunrise: nil,
            sunset: nil,
            source: WeatherFormatter.localized("预览", "Preview")
        )
        return WeatherWidgetEntry(
            date: Date(),
            profile: .default,
            snapshot: snapshot,
            freshness: .live,
            configIntent: .sample,
            showsSource: false
        )
    }
}
