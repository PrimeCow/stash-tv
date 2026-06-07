import SwiftUI

struct RootView: View {
    @Environment(ServerConfig.self) private var config
    @Environment(AppLock.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    appLock.lock()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch appLock.status {
        case .needsSetup:
            PINSetupView(appLock: appLock)
        case .locked:
            PINLockView(appLock: appLock)
        case .unlocked:
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
}
