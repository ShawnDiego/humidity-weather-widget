import SwiftUI
import WeatherCore

enum AppTab: Hashable {
    case weather
    case profiles
    case location
    case settings
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.locale) private var locale
    @State private var deepLinkProfileID: UUID?
    @State private var selectedTab: AppTab = .weather

    var body: some View {
        ZStack {
            AppGradientBackground(category: model.currentWeatherCategory, isNight: model.currentWeatherIsNight)

            TabView(selection: $selectedTab) {
                WeatherHomeView { tab in
                    selectedTab = tab
                }
                .tabItem {
                    Label(loc("天气", "Weather"), systemImage: "cloud.sun.fill")
                }
                .tag(AppTab.weather)

                ProfileListView(highlightProfileID: deepLinkProfileID)
                    .tabItem {
                        Label(loc("方案", "Profiles"), systemImage: "square.grid.2x2")
                    }
                    .tag(AppTab.profiles)

                LocationSettingsView()
                    .tabItem {
                        Label(loc("定位", "Location"), systemImage: "location.fill")
                    }
                    .tag(AppTab.location)

                AppSettingsView()
                    .tabItem {
                        Label(loc("设置", "Settings"), systemImage: "slider.horizontal.3")
                    }
                    .tag(AppTab.settings)
            }
            .tint(AppPalette.accent)
            .fontDesign(.rounded)
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "humidity", url.host == "weather",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let profileId = components.queryItems?.first(where: { $0.name == "profileId" })?.value,
              let uuid = UUID(uuidString: profileId)
        else {
            return
        }

        deepLinkProfileID = uuid
    }

    private func loc(_ zh: String, _ en: String) -> String {
        WeatherFormatter.prefersChineseSystem(locale) ? zh : en
    }
}
