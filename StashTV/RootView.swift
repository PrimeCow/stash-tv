import SwiftUI

struct RootView: View {
    @Environment(ServerConfig.self) private var config

    var body: some View {
        if config.isConfigured {
            TabView {
                BrowseView()
                    .tabItem { Label("Scenes", systemImage: "play.rectangle.fill") }
                MarkersBrowseView()
                    .tabItem { Label("Markers", systemImage: "bookmark.fill") }
                GroupsBrowseView()
                    .tabItem { Label("Groups", systemImage: "rectangle.stack.fill") }
            }
        } else {
            ServerSetupView()
        }
    }
}
