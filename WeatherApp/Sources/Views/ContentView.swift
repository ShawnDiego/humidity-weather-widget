import SwiftUI
import WeatherCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.locale) private var locale
    @State private var deepLinkProfileID: UUID?

    var body: some View {
        ZStack {
            AppGradientBackground()

            TabView {
                ProfileListView(highlightProfileID: deepLinkProfileID)
                    .tabItem {
                        Label(loc("方案", "Profiles"), systemImage: "square.grid.2x2")
                    }

                LocationSettingsView()
                    .tabItem {
                        Label(loc("定位", "Location"), systemImage: "location.fill")
                    }

                AppSettingsView()
                    .tabItem {
                        Label(loc("设置", "Settings"), systemImage: "slider.horizontal.3")
                    }
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
