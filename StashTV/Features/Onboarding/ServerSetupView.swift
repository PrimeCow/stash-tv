import SwiftUI

struct ServerSetupView: View {
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 8) {
                Text("Connect to Stash")
                    .font(.largeTitle).bold()
                Text("Enter your Stash server URL and an optional API key.")
                    .foregroundStyle(.secondary)
            }

            // No onSaved action needed: once the config is set, RootView swaps
            // this screen for the main TabView automatically.
            ConnectionForm(submitTitle: "Save & Continue")
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
