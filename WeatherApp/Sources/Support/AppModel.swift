import Foundation
import SwiftUI
import WidgetKit
import WeatherCore

@MainActor
final class AppModel: ObservableObject {
    @Published var profiles: [DisplayProfile] = []
    @Published var settings = WeatherSettings()
    @Published var storedLocation: StoredLocation?
    @Published var statusMessage: String = ""

    let factory: WeatherServiceFactory

    init(factory: WeatherServiceFactory = WeatherServiceFactory()) {
        self.factory = factory
    }

    func loadInitialData() async {
        profiles = await factory.profileStore.fetchProfiles()
        settings = await factory.settingsStore.load()
        storedLocation = await factory.locationStore.load()
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
    }

    func saveLocation(_ location: StoredLocation) async {
        await factory.locationStore.save(location)
        storedLocation = await factory.locationStore.load()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func testConnectivity() async {
        statusMessage = "测试中..."
        let settings = await factory.settingsStore.load()
        let provider = factory.makeWeatherProvider(settings: settings)

        do {
            let snapshot = try await provider.fetchCurrent(lat: 39.9042, lon: 116.4074, tz: "Asia/Shanghai")
            statusMessage = "成功：\(snapshot.source) 返回可用数据"
        } catch {
            statusMessage = "失败：\(error.localizedDescription)"
        }
    }
}
