import Foundation
import VaulthoundModels

/// Detects API keys and secrets by pattern matching on key names and value prefixes.
public struct SecretDetector: Sendable {

    public init() {}

    /// Detect whether a variable is likely a secret based on its key and value.
    public func detect(key: String, value: String) -> SecretCategory? {
        // Check value prefix first (most reliable signal)
        if let category = detectByValuePrefix(value) {
            return category
        }

        // Check key name patterns
        if let category = detectByKeyName(key) {
            return category
        }

        // Check for high-entropy strings that look like tokens
        if looksLikeToken(value) {
            return .generic
        }

        return nil
    }

    /// Returns true if the value appears to be a secret that should be stored in Keychain.
    public func isLikelySecret(key: String, value: String) -> Bool {
        detect(key: key, value: value) != nil
    }

    // MARK: - Value Prefix Detection

    private func detectByValuePrefix(_ value: String) -> SecretCategory? {
        let prefixMap: [(String, SecretCategory)] = [
            ("sk-ant-", .anthropic),
            ("sk-proj-", .openAI),
            ("sk-", .openAI),
            ("sk_live_", .stripe),
            ("sk_test_", .stripe),
            ("pk_live_", .stripe),
            ("pk_test_", .stripe),
            ("rk_live_", .stripe),
            ("rk_test_", .stripe),
            ("AKIA", .aws),
            ("ASIA", .aws),
            ("ghp_", .github),
            ("gho_", .github),
            ("ghu_", .github),
            ("ghs_", .github),
            ("github_pat_", .github),
            ("AIza", .google),
            ("r8_", .replicate),
            ("hf_", .huggingFace),
            ("gsk_", .groq),
            ("fw_", .fireworks),
        ]

        for (prefix, category) in prefixMap {
            if value.hasPrefix(prefix) {
                return category
            }
        }

        return nil
    }

    // MARK: - Key Name Detection

    private static let secretKeyPatterns: [String] = [
        "SECRET", "TOKEN", "API_KEY", "APIKEY", "API_SECRET",
        "PASSWORD", "PASSWD", "PRIVATE_KEY", "ACCESS_KEY",
        "AUTH_TOKEN", "BEARER", "CREDENTIALS", "CLIENT_SECRET",
        "SIGNING_KEY", "ENCRYPTION_KEY", "JWT_SECRET",
    ]

    private func detectByKeyName(_ key: String) -> SecretCategory? {
        let upper = key.uppercased()

        for pattern in Self.secretKeyPatterns {
            if upper.contains(pattern) {
                return categorizeByKeyName(upper)
            }
        }

        return nil
    }

    private func categorizeByKeyName(_ key: String) -> SecretCategory {
        if key.contains("OPENAI") { return .openAI }
        if key.contains("ANTHROPIC") || key.contains("CLAUDE") { return .anthropic }
        if key.contains("STRIPE") { return .stripe }
        if key.contains("AWS") { return .aws }
        if key.contains("GITHUB") || key.contains("GH_") { return .github }
        if key.contains("GOOGLE") || key.contains("GCP") || key.contains("FIREBASE") { return .google }
        if key.contains("MISTRAL") { return .mistral }
        if key.contains("COHERE") { return .cohere }
        if key.contains("REPLICATE") { return .replicate }
        if key.contains("HUGGING") || key.contains("HF_") { return .huggingFace }
        if key.contains("TOGETHER") { return .togetherAI }
        if key.contains("GROQ") { return .groq }
        if key.contains("FIREWORKS") { return .fireworks }
        return .generic
    }

    // MARK: - High Entropy Detection

    /// Checks if a string looks like a random token (high entropy, sufficient length).
    private func looksLikeToken(_ value: String) -> Bool {
        guard value.count >= 20 else { return false }

        let alphanumeric = value.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        guard Double(alphanumeric.count) / Double(value.count) > 0.8 else { return false }

        let uniqueChars = Set(value)
        let ratio = Double(uniqueChars.count) / Double(value.count)

        // High-entropy strings have many unique characters relative to length
        return ratio > 0.4 && value.count >= 24
    }
}
