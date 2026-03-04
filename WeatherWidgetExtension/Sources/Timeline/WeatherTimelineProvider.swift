import Foundation
import WeatherCore
import WidgetKit

struct WeatherTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = WeatherWidgetConfigurationIntent
    typealias Entry = WeatherWidgetEntry

    func placeholder(in context: Context) -> WeatherWidgetEntry {
        .placeholder
    }

    func snapshot(for configuration: WeatherWidgetConfigurationIntent, in context: Context) async -> WeatherWidgetEntry {
        if context.isPreview {
            return .placeholder
        }
        return await loadEntry(for: configuration, now: Date())
    }

    func timeline(for configuration: WeatherWidgetConfigurationIntent, in context: Context) async -> Timeline<WeatherWidgetEntry> {
        let now = Date()
        let entry = await loadEntry(for: configuration, now: now)

        let entries: [WeatherWidgetEntry] = (0 ... 12).map { index in
            let date = Calendar.current.date(byAdding: .minute, value: index * 30, to: now) ?? now
            return WeatherWidgetEntry(
                date: date,
                profile: entry.profile,
                snapshot: entry.snapshot,
                freshness: entry.freshness,
                configIntent: configuration,
                showsSource: entry.showsSource
            )
        }

        let nextRefreshMinutes = entry.freshness == .live ? 30 : 60
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: nextRefreshMinutes, to: now) ?? now.addingTimeInterval(Double(nextRefreshMinutes) * 60)
        return Timeline(entries: entries, policy: .after(nextRefresh))
    }

    private func loadEntry(for configuration: WeatherWidgetConfigurationIntent, now: Date) async -> WeatherWidgetEntry {
        let factory = WeatherServiceFactory()
        let settings = await factory.loadSettings()
        let profile = await factory.profileStore.profile(with: configuration.resolvedProfileID)

        do {
            let location = try await factory.resolveLocation(
                mode: configuration.resolvedLocationMode,
                manualCity: configuration.manualCity,
                manualCoordinates: nil
            )
            let repository = factory.makeRepository(settings: settings)
            let result = try await repository.fetchSnapshot(for: location, now: now)

            return WeatherWidgetEntry(
                date: now,
                profile: profile,
                snapshot: result.snapshot,
                freshness: result.freshness,
                configIntent: configuration,
                showsSource: settings.debugShowDataSource
            )
        } catch {
            let fallback = WeatherWidgetEntry.placeholder
            var snapshot = fallback.snapshot
            snapshot.source = WeatherFormatter.localized("错误", "Error")
            snapshot.locationName = configuration.manualCity?.isEmpty == false ? configuration.manualCity! : fallback.snapshot.locationName

            return WeatherWidgetEntry(
                date: now,
                profile: profile,
                snapshot: snapshot,
                freshness: .stale,
                configIntent: configuration,
                showsSource: settings.debugShowDataSource
            )
        }
    }
}
