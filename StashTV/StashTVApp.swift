import SwiftUI

@main
struct StashTVApp: App {
    @State private var config = ServerConfig()
    @State private var prefs = FilterPreferences()
    @State private var appLock = AppLock()

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView()
                .environment(config)
                .environment(prefs)
                .environment(appLock)
                .preferredColorScheme(.dark)
        }
    }
}
