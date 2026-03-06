import SwiftUI
import WidgetKit

@main
struct WeatherAppMain: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasCompletedInitialLoad = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .task {
                    guard !hasCompletedInitialLoad else { return }
                    hasCompletedInitialLoad = true
                    await model.loadInitialData()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, hasCompletedInitialLoad else { return }
            WidgetCenter.shared.reloadAllTimelines()
            Task {
                await model.loadInitialData()
            }
        }
    }
}
