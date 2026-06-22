import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ServerConfig.self) private var config
    @Environment(AppLock.self) private var appLock

    @State private var saved = false
    @State private var showChangePIN = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 44) {
                HStack {
                    Text("Settings")
                        .font(.largeTitle).bold()
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.bordered)
                }
                .focusSection()

                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Server")
                    ConnectionForm(submitTitle: "Save Changes") { saved = true }
                    if saved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Security")
                    Button {
                        showChangePIN = true
                    } label: {
                        Label("Change PIN", systemImage: "lock.rotation")
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 16) {
                    sectionHeader("Account")
                    Button {
                        config.serverURL = nil
                        config.apiKey = nil
                        dismiss()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(.bordered)
                    Text("Clears the saved server URL and API key from this device.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Text("stash-tv \(appVersion)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(80)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black.ignoresSafeArea())
        .fullScreenCover(isPresented: $showChangePIN) {
            ChangePINView(appLock: appLock)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.headline)
            .foregroundStyle(.secondary)
            .tracking(1.5)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "v\(version) (\(build))"
    }
}
