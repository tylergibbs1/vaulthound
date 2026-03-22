import Foundation
import LocalAuthentication

/// Wraps Touch ID / password authentication as a gate before revealing secrets.
public struct BiometricGate: Sendable {

    public enum BiometricError: Error, LocalizedError {
        case notAvailable
        case authenticationFailed(String)
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .notAvailable: return "Biometric authentication is not available on this device"
            case .authenticationFailed(let reason): return "Authentication failed: \(reason)"
            case .cancelled: return "Authentication was cancelled"
            }
        }
    }

    public init() {}

    /// Returns true if Touch ID (or device password) is available.
    public var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Authenticates the user with Touch ID. Falls back to device password if Touch ID fails.
    public func authenticate(reason: String = "Authenticate to reveal secret") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)

        guard canEvaluate else {
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            guard success else {
                throw BiometricError.authenticationFailed("Unknown error")
            }
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.cancelled
            default:
                throw BiometricError.authenticationFailed(laError.localizedDescription)
            }
        }
    }
}
