import Foundation
import Security

/// CRUD operations for Keychain items scoped to the Vaulthound shared access group.
///
/// Uses the Data Protection keychain (`kSecUseDataProtectionKeychain`) which avoids
/// legacy Keychain password prompts in unsigned/ad-hoc debug builds.
///
/// Each secret is stored as a generic password with:
/// - service: "com.vaulthound"
/// - account: "{projectID}/{envName}/{variableKey}"
public struct KeychainAccess: Sendable {

    public static let service = "com.vaulthound"
    public static let accessGroup = "com.vaulthound.shared"

    public enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)
        case dataConversionFailed
        case itemNotFound

        public var errorDescription: String? {
            switch self {
            case .saveFailed(let status): return "Keychain save failed: \(status) (\(SecCopyErrorMessageString(status, nil) as String? ?? "unknown"))"
            case .readFailed(let status): return "Keychain read failed: \(status) (\(SecCopyErrorMessageString(status, nil) as String? ?? "unknown"))"
            case .deleteFailed(let status): return "Keychain delete failed: \(status) (\(SecCopyErrorMessageString(status, nil) as String? ?? "unknown"))"
            case .dataConversionFailed: return "Failed to convert Keychain data to string"
            case .itemNotFound: return "Keychain item not found"
            }
        }
    }

    public init() {}

    /// Builds the Keychain account identifier from components.
    public static func accountKey(projectID: String, envName: String, variableKey: String) -> String {
        "\(projectID)/\(envName)/\(variableKey)"
    }

    // MARK: - Base Query

    /// Whether to use the Data Protection keychain (avoids password prompts in debug builds).
    /// Disabled in SPM test bundles which lack the required entitlement.
    public var useDataProtectionKeychain = true

    /// Base query attributes shared by all operations.
    private func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        if useDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    private var serviceQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
        ]
        if useDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    // MARK: - CRUD

    public func save(account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        // Try to update first
        let updateStatus = SecItemUpdate(
            baseQuery(account: account) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecSuccess { return }

        if updateStatus != errSecItemNotFound {
            SecItemDelete(baseQuery(account: account) as CFDictionary)
        }

        var addQuery = baseQuery(account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.saveFailed(addStatus)
        }
    }

    public func read(account: String) throws -> String {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.readFailed(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        return string
    }

    public func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    public func exists(account: String) -> Bool {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = false
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    public func listAccounts() throws -> [String] {
        var query = serviceQuery
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitAll

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return [] }

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            throw KeychainError.readFailed(status)
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    public func deleteAll() throws {
        let status = SecItemDelete(serviceQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
