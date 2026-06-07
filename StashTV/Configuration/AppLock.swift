import Foundation
import Observation

@Observable
@MainActor
final class AppLock {
    enum Status: Equatable {
        case needsSetup
        case locked
        case unlocked
    }

    private(set) var status: Status
    private(set) var lastError: String?

    private let keychain: KeychainStore
    private static let pinAccount = "stashtv.appPIN"

    init(keychain: KeychainStore = .shared) {
        self.keychain = keychain
        let existing = try? keychain.read(account: Self.pinAccount)
        self.status = (existing?.isEmpty == false) ? .locked : .needsSetup
    }

    func setupPIN(_ pin: String) {
        guard isValidPIN(pin) else { return }
        try? keychain.write(pin, account: Self.pinAccount)
        lastError = nil
        status = .unlocked
    }

    func verify(_ pin: String) -> Bool {
        guard let stored = try? keychain.read(account: Self.pinAccount),
              !stored.isEmpty,
              stored == pin else {
            lastError = "Incorrect PIN"
            return false
        }
        lastError = nil
        status = .unlocked
        return true
    }

    func lock() {
        if status == .unlocked { status = .locked }
    }

    private func isValidPIN(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }
}
