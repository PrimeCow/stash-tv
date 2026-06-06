import SwiftUI

struct RootView: View {
    @Environment(ServerConfig.self) private var config

    var body: some View {
        if config.isConfigured {
            BrowseView()
        } else {
            ServerSetupView()
        }
    }
}
