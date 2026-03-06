import Foundation
import SwiftUI
import WidgetKit
import WeatherCore

enum WeatherLoadState: Equatable {
    case idle
    case loading
    case refreshing
    case loaded
    case emptyLocation
    case failed
}

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [DisplayProfile] = []
    @Published var settings = WeatherSettings()
    @Published var storedLocation: StoredLocation?
    @Published var statusMessage: String = ""
    @Published var currentSnapshot: SnapshotResult?
    @Published var weatherLoadState: WeatherLoadState = .idle
    @Published var weatherErrorMessage: String = ""

    let factory: WeatherServiceFactory
    private var weatherRequestSequence = 0

    init(factory: WeatherServiceFactory = WeatherServiceFactory()) {
        self.factory = factory
    }

    var currentWeatherCategory: WeatherConditionCategory? {
        guard let conditionCode = currentSnapshot?.snapshot.conditionCode else {
            return nil
        }
        return WeatherFormatter.weatherCategory(for: conditionCode)
    }

    var currentWeatherIsNight: Bool {
        guard let snapshot = currentSnapshot?.snapshot else {
            return false
        }

        if let sunrise = snapshot.sunrise, let sunset = snapshot.sunset {
            return snapshot.timestamp < sunrise || snapshot.timestamp >= sunset
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: snapshot.timezone) ?? .current
        let hour = calendar.component(.hour, from: snapshot.timestamp)
        return hour < 6 || hour >= 18
    }

    func loadInitialData() async {
        profiles = await factory.profileStore.fetchProfiles()
        settings = await factory.settingsStore.load()
        storedLocation = await factory.locationStore.load()
        await refreshCurrentWeather(force: currentSnapshot != nil)
    }

    func refreshProfiles() async {
        profiles = await factory.profileStore.fetchProfiles()
    }

    func upsertProfile(_ profile: DisplayProfile) async {
        await factory.profileStore.upsert(profile)
        profiles = await factory.profileStore.fetchProfiles()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deleteProfile(id: UUID) async {
        await factory.profileStore.delete(id: id)
        profiles = await factory.profileStore.fetchProfiles()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func saveSettings(_ settings: WeatherSettings) async {
        await factory.settingsStore.save(settings)
        self.settings = await factory.settingsStore.load()
        WidgetCenter.shared.reloadAllTimelines()
        await refreshCurrentWeather(force: true)
    }

    func saveLocation(_ location: StoredLocation) async {
        await factory.locationStore.save(location)
        storedLocation = await factory.locationStore.load()
        WidgetCenter.shared.reloadAllTimelines()
        await refreshCurrentWeather(force: true)
    }

    func refreshCurrentWeather(force: Bool = false) async {
        guard let location = storedLocation?.asResolvedLocation else {
            currentSnapshot = nil
            weatherErrorMessage = ""
            weatherLoadState = .emptyLocation
            return
        }

        weatherRequestSequence += 1
        let requestSequence = weatherRequestSequence
        let nextState: WeatherLoadState

        if currentSnapshot == nil {
            nextState = .loading
        } else if force {
            nextState = .refreshing
        } else {
            nextState = .loading
        }

        weatherErrorMessage = ""
        weatherLoadState = nextState

        let latestSettings = await factory.settingsStore.load()
        let repository = factory.makeRepository(settings: latestSettings)

        do {
            let snapshot = try await repository.fetchSnapshot(for: location)
            guard requestSequence == weatherRequestSequence else { return }
            currentSnapshot = snapshot
            weatherErrorMessage = ""
            weatherLoadState = .loaded
        } catch {
            guard requestSequence == weatherRequestSequence else { return }
            currentSnapshot = nil
            weatherErrorMessage = error.localizedDescription
            weatherLoadState = .failed
        }
    }

    func testConnectivity() async {
        statusMessage = loc("测试中...", "Testing...")
        let settings = await factory.settingsStore.load()
        let provider = factory.makeWeatherProvider(settings: settings)

        do {
            let snapshot = try await provider.fetchCurrent(lat: 39.9042, lon: 116.4074, tz: "Asia/Shanghai")
            statusMessage = "\(loc("成功", "Success")): \(snapshot.source) \(loc("返回可用数据", "returned valid data"))"
        } catch {
            statusMessage = "\(loc("失败", "Failed")): \(error.localizedDescription)"
        }
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem() ? zh : en
    }
}
