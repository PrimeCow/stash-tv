import SwiftUI

/// Server URL + API key fields, a phone-pairing handoff, and a live connection
/// test. Shared by the onboarding setup screen and the Settings screen; pre-fills
/// from the current config so it doubles as an editor.
struct ConnectionForm: View {
    let submitTitle: String
    var onSaved: () -> Void = {}

    @Environment(ServerConfig.self) private var config

    @State private var serverText = ""
    @State private var apiKeyText = ""
    @State private var testState: TestState = .idle
    @State private var showPairing = false

    private enum TestState: Equatable {
        case idle
        case testing
        case ok(version: String)
        case failed(message: String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 24) {
                LabeledField(label: "Server URL", placeholder: "https://stash.example.com", text: $serverText)
                LabeledField(label: "API Key (optional)", placeholder: "paste API key", text: $apiKeyText)
            }

            Button {
                showPairing = true
            } label: {
                Label("Enter from Phone", systemImage: "iphone.and.arrow.forward")
            }

            statusView

            HStack(spacing: 24) {
                Button("Test Connection", action: testConnection)
                    .disabled(parsedURL == nil || testState == .testing)
                Button(submitTitle, action: save)
                    .disabled(parsedURL == nil)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: 900, alignment: .leading)
        .onAppear {
            serverText = config.serverURL?.absoluteString ?? ""
            apiKeyText = config.apiKey ?? ""
        }
        .fullScreenCover(isPresented: $showPairing) {
            PairingView { url, key in
                serverText = url
                apiKeyText = key ?? ""
                testState = .idle
            }
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
                .multilineTextAlignment(.leading)
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
        onSaved()
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if !text.isEmpty {
                    Button(role: .destructive) {
                        text = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                            .font(.caption)
                    }
                }
            }
            TextField(placeholder, text: $text)
                .font(.title3)
        }
    }
}
