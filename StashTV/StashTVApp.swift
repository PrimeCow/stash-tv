import SwiftUI

@main
struct StashTVApp: App {
    @State private var config = ServerConfig()

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView()
                .environment(config)
                .preferredColorScheme(.dark)
        }
    }
}
