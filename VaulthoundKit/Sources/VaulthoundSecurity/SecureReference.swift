import Foundation

/// Models the `$ref` pointer format used in `.vaulthound/` environment JSON files.
///
/// Format: `keychain:vh.{projectName}.{envName}.{variableKey}`
public struct SecureReference: Codable, Sendable, Hashable {

    public let ref: String

    public var keychainAccount: String? {
        guard ref.hasPrefix("keychain:") else { return nil }
        return String(ref.dropFirst(9))
    }

    public init(projectName: String, envName: String, variableKey: String) {
        self.ref = "keychain:vh.\(projectName).\(envName).\(variableKey)"
    }

    public init(ref: String) {
        self.ref = ref
    }

    /// Builds a Keychain account key from this reference.
    /// Returns nil if this isn't a keychain reference.
    public var keychainAccountKey: String? {
        guard let account = keychainAccount else { return nil }
        // Convert vh.projectName.envName.variableKey -> projectName/envName/variableKey
        let parts = account.split(separator: ".")
        guard parts.count >= 4, parts.first == "vh" else { return nil }
        return parts.dropFirst().joined(separator: "/")
    }

    public static func fromKeychainAccount(_ account: String) -> SecureReference {
        // Convert projectName/envName/variableKey -> keychain:vh.projectName.envName.variableKey
        let dotted = account.replacingOccurrences(of: "/", with: ".")
        return SecureReference(ref: "keychain:vh.\(dotted)")
    }
}
