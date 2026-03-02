import SwiftUI
import WidgetKit

@main
struct WeatherAppMain: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .task {
                    await model.loadInitialData()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            WidgetCenter.shared.reloadAllTimelines()
            Task {
                await model.loadInitialData()
            }
        }
    }
}
