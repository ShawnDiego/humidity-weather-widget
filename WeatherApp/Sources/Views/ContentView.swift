import SwiftUI
import WeatherCore

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var deepLinkProfileID: UUID?

    var body: some View {
        TabView {
            ProfileListView(highlightProfileID: deepLinkProfileID)
                .tabItem {
                    Label("方案", systemImage: "list.bullet.rectangle")
                }

            LocationSettingsView()
                .tabItem {
                    Label("定位", systemImage: "location")
                }

            AppSettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
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
}
