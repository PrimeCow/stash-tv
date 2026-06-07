import SwiftUI

@main
struct StashTVApp: App {
    @State private var config = ServerConfig()
    @State private var prefs = FilterPreferences()

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView()
                .environment(config)
                .environment(prefs)
                .preferredColorScheme(.dark)
        }
    }
}
