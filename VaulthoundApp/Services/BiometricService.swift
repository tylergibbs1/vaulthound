import Foundation
import VaulthoundSecurity

/// App-level wrapper around BiometricGate.
@MainActor
final class BiometricService {
    static let shared = BiometricService()

    private let gate = BiometricGate()

    private init() {}

    var isAvailable: Bool { gate.isAvailable }

    func authenticate(reason: String = "Authenticate to reveal secret") async throws {
        try await gate.authenticate(reason: reason)
    }
}
