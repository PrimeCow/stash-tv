import SwiftUI

struct ServerSetupView: View {
    @Environment(ServerConfig.self) private var config

    @State private var serverText = ""
    @State private var apiKeyText = ""
    @State private var testState: TestState = .idle

    private enum TestState: Equatable {
        case idle
        case testing
        case ok(version: String)
        case failed(message: String)
    }

    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 8) {
                Text("Connect to Stash")
                    .font(.largeTitle).bold()
                Text("Enter your Stash server URL and an optional API key.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 24) {
                LabeledField(label: "Server URL", placeholder: "https://stash.example.com", text: $serverText)
                LabeledField(label: "API Key (optional)", placeholder: "paste API key", text: $apiKeyText, secure: true)
            }
            .frame(maxWidth: 900)

            statusView

            HStack(spacing: 24) {
                Button("Test Connection", action: testConnection)
                    .disabled(parsedURL == nil || testState == .testing)
                Button("Save & Continue", action: save)
                    .disabled(parsedURL == nil)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            serverText = config.serverURL?.absoluteString ?? ""
            apiKeyText = config.apiKey ?? ""
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView("Contacting server…")
        case .ok(let version):
            Label("Connected to Stash \(version)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private var parsedURL: URL? {
        let trimmed = serverText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else { return nil }
        return url
    }

    private func testConnection() {
        guard let url = parsedURL else { return }
        let key = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        testState = .testing
        Task {
            do {
                let client = StashClient(serverURL: url, apiKey: key.isEmpty ? nil : key)
                let result = try await client.execute(VersionQuery())
                testState = .ok(version: result.version.version)
            } catch {
                testState = .failed(message: (error as? LocalizedError)?.errorDescription ?? "\(error)")
            }
        }
    }

    private func save() {
        guard let url = parsedURL else { return }
        let key = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        config.apiKey = key.isEmpty ? nil : key
        config.serverURL = url
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var secure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .font(.title3)
        }
    }
}
