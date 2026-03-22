import Testing
import Foundation
@testable import VaulthoundSecurity

@Suite("KeychainAccess")
struct KeychainAccessTests {

    /// Tests use the legacy keychain (no Data Protection) since SPM test
    /// bundles lack the required entitlement.
    private func makeKeychain() -> KeychainAccess {
        var kc = KeychainAccess()
        kc.useDataProtectionKeychain = false
        return kc
    }

    @Test("Account key construction")
    func accountKey() {
        let key = KeychainAccess.accountKey(projectID: "proj1", envName: "staging", variableKey: "API_KEY")
        #expect(key == "proj1/staging/API_KEY")
    }

    @Test("Save and read round-trip")
    func saveAndRead() throws {
        let keychain = makeKeychain()
        let account = "test/\(UUID().uuidString)/TEST_KEY"

        try keychain.save(account: account, value: "test-secret-value")
        let retrieved = try keychain.read(account: account)
        #expect(retrieved == "test-secret-value")

        // Cleanup
        try keychain.delete(account: account)
    }

    @Test("Read nonexistent item throws itemNotFound")
    func readNonexistent() {
        let keychain = makeKeychain()
        #expect(throws: KeychainAccess.KeychainError.self) {
            try keychain.read(account: "nonexistent/\(UUID().uuidString)/NOPE")
        }
    }

    @Test("Update existing item")
    func updateExisting() throws {
        let keychain = makeKeychain()
        let account = "test/\(UUID().uuidString)/UPDATE_KEY"

        try keychain.save(account: account, value: "original")
        try keychain.save(account: account, value: "updated")
        let retrieved = try keychain.read(account: account)
        #expect(retrieved == "updated")

        try keychain.delete(account: account)
    }

    @Test("Delete removes item")
    func deleteItem() throws {
        let keychain = makeKeychain()
        let account = "test/\(UUID().uuidString)/DELETE_KEY"

        try keychain.save(account: account, value: "to-delete")
        try keychain.delete(account: account)
        #expect(!keychain.exists(account: account))
    }

    @Test("Exists returns correct result")
    func exists() throws {
        let keychain = makeKeychain()
        let account = "test/\(UUID().uuidString)/EXISTS_KEY"

        #expect(!keychain.exists(account: account))
        try keychain.save(account: account, value: "val")
        #expect(keychain.exists(account: account))

        try keychain.delete(account: account)
    }
}
