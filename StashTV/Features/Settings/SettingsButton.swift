import SwiftUI

/// Gear button for the browse-tab headers. Owns its own presentation so it can be
/// dropped into any header without each view managing settings state.
struct SettingsButton: View {
    @State private var showSettings = false

    var body: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Settings")
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
