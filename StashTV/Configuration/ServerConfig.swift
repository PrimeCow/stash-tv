import Foundation
import Observation

@Observable
@MainActor
final class ServerConfig {
    private enum Keys {
        static let serverURL = "stashtv.serverURL"
        static let keychainAccount = "stashtv.apiKey"
    }

    var serverURL: URL? {
        didSet { persistServerURL() }
    }

    var apiKey: String? {
        didSet { persistApiKey() }
    }

    var isConfigured: Bool { serverURL != nil }

    init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = .shared,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.defaults = defaults
        self.keychain = keychain
        if let raw = defaults.string(forKey: Keys.serverURL), let url = URL(string: raw) {
            self.serverURL = url
        }
        self.apiKey = try? keychain.read(account: Keys.keychainAccount)

        if let envURL = environment["STASH_SERVER_URL"].flatMap(URL.init(string:)) {
            self.serverURL = envURL
        }
        if let envKey = environment["STASH_API_KEY"], !envKey.isEmpty {
            self.apiKey = envKey
        }
    }

    private let defaults: UserDefaults
    private let keychain: KeychainStore

    private func persistServerURL() {
        if let serverURL {
            defaults.set(serverURL.absoluteString, forKey: Keys.serverURL)
        } else {
            defaults.removeObject(forKey: Keys.serverURL)
        }
    }

    private func persistApiKey() {
        if let apiKey, !apiKey.isEmpty {
            try? keychain.write(apiKey, account: Keys.keychainAccount)
        } else {
            try? keychain.delete(account: Keys.keychainAccount)
        }
    }
}
