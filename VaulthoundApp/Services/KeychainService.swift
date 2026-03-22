import Foundation
import VaulthoundSecurity

/// App-level wrapper around KeychainAccess for convenience.
@MainActor
final class KeychainService {
    static let shared = KeychainService()

    private let keychain = KeychainAccess()

    private init() {}

    func save(account: String, value: String) throws {
        try keychain.save(account: account, value: value)
    }

    func read(account: String) throws -> String {
        try keychain.read(account: account)
    }

    func delete(account: String) throws {
        try keychain.delete(account: account)
    }

    func exists(account: String) -> Bool {
        keychain.exists(account: account)
    }
}
