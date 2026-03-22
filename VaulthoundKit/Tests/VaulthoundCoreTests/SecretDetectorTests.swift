import Testing
@testable import VaulthoundCore
import VaulthoundModels

@Suite("SecretDetector")
struct SecretDetectorTests {
    let detector = SecretDetector()

    @Test("Detects OpenAI keys by sk- prefix")
    func openAIByPrefix() {
        let result = detector.detect(key: "SOME_KEY", value: "sk-proj-abc123def456")
        #expect(result == .openAI)
    }

    @Test("Detects Anthropic keys by sk-ant- prefix")
    func anthropicByPrefix() {
        let result = detector.detect(key: "SOME_KEY", value: "sk-ant-abc123def456")
        #expect(result == .anthropic)
    }

    @Test("Detects Stripe keys by sk_live_ prefix")
    func stripeByPrefix() {
        let result = detector.detect(key: "KEY", value: "sk_live_abcdef123456789")
        #expect(result == .stripe)
    }

    @Test("Detects AWS keys by AKIA prefix")
    func awsByPrefix() {
        let result = detector.detect(key: "KEY", value: "AKIAIOSFODNN7EXAMPLE")
        #expect(result == .aws)
    }

    @Test("Detects GitHub tokens by ghp_ prefix")
    func githubByPrefix() {
        let result = detector.detect(key: "TOKEN", value: "ghp_abcdefghijklmnopqrstuvwxyz1234567890")
        #expect(result == .github)
    }

    @Test("Detects secrets by key name containing SECRET")
    func secretByKeyName() {
        let result = detector.detect(key: "MY_SECRET_VALUE", value: "plainvalue")
        #expect(result != nil)
    }

    @Test("Detects secrets by key name containing API_KEY")
    func apiKeyByKeyName() {
        let result = detector.detect(key: "OPENAI_API_KEY", value: "abc")
        #expect(result == .openAI)
    }

    @Test("Returns nil for non-secret values")
    func nonSecret() {
        let result = detector.detect(key: "BASE_URL", value: "https://example.com")
        #expect(result == nil)
    }

    @Test("Returns nil for short values")
    func shortValues() {
        let result = detector.detect(key: "PORT", value: "3000")
        #expect(result == nil)
    }

    @Test("Detects high-entropy tokens")
    func highEntropy() {
        let result = detector.detect(key: "SOME_VAR", value: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6")
        #expect(result == .generic)
    }

    @Test("isLikelySecret returns true for API keys")
    func isLikelySecret() {
        #expect(detector.isLikelySecret(key: "KEY", value: "sk-ant-abc123"))
        #expect(!detector.isLikelySecret(key: "URL", value: "https://example.com"))
    }

    @Test("Detects Groq keys by gsk_ prefix")
    func groqByPrefix() {
        let result = detector.detect(key: "KEY", value: "gsk_abc123def456ghi789")
        #expect(result == .groq)
    }

    @Test("Detects HuggingFace keys by hf_ prefix")
    func huggingFaceByPrefix() {
        let result = detector.detect(key: "KEY", value: "hf_abcdefghijklmnop")
        #expect(result == .huggingFace)
    }

    @Test("Detects Replicate keys by r8_ prefix")
    func replicateByPrefix() {
        let result = detector.detect(key: "KEY", value: "r8_abcdefghijklmnop")
        #expect(result == .replicate)
    }
}
