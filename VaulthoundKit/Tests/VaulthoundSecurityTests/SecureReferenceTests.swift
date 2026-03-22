import Testing
import Foundation
@testable import VaulthoundSecurity

@Suite("SecureReference")
struct SecureReferenceTests {

    @Test("Constructs keychain reference from components")
    func constructsRef() {
        let ref = SecureReference(projectName: "myapp", envName: "staging", variableKey: "API_KEY")
        #expect(ref.ref == "keychain:vh.myapp.staging.API_KEY")
    }

    @Test("Extracts keychain account from ref string")
    func extractsAccount() {
        let ref = SecureReference(ref: "keychain:vh.myapp.staging.API_KEY")
        #expect(ref.keychainAccount == "vh.myapp.staging.API_KEY")
    }

    @Test("Converts ref to keychain account key format")
    func convertsToAccountKey() {
        let ref = SecureReference(ref: "keychain:vh.myapp.staging.API_KEY")
        #expect(ref.keychainAccountKey == "myapp/staging/API_KEY")
    }

    @Test("Returns nil for non-keychain ref")
    func nonKeychainRef() {
        let ref = SecureReference(ref: "vault:some/other/ref")
        #expect(ref.keychainAccount == nil)
        #expect(ref.keychainAccountKey == nil)
    }

    @Test("Round-trips from keychain account to ref and back")
    func roundtrip() {
        let original = "myproject/production/STRIPE_KEY"
        let ref = SecureReference.fromKeychainAccount(original)
        #expect(ref.ref == "keychain:vh.myproject.production.STRIPE_KEY")
        #expect(ref.keychainAccountKey == original)
    }
}
