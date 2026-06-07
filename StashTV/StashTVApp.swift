import SwiftUI

@main
struct StashTVApp: App {
    @State private var config = ServerConfig()
    @State private var prefs = FilterPreferences()
    @State private var appLock = AppLock()
    @State private var sceneStats = SceneStatsStore()

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView()
                .environment(config)
                .environment(prefs)
                .environment(appLock)
                .environment(sceneStats)
                .preferredColorScheme(.dark)
        }
    }
}
