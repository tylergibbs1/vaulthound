import SwiftData
import Foundation

public enum SecretCategory: String, Codable, Sendable, CaseIterable {
    case openAI
    case anthropic
    case stripe
    case aws
    case github
    case google
    case mistral
    case cohere
    case replicate
    case huggingFace
    case togetherAI
    case groq
    case fireworks
    case generic
}

@Model
public final class Variable {
    @Attribute(.unique) public var id: UUID
    public var key: String
    public var value: String
    public var isSecret: Bool
    public var keychainRef: String?
    public var projectEnvironment: ProjectEnvironment?
    public var detectedCategory: SecretCategory?
    public var isMissing: Bool
    public var sortOrder: Int

    public var displayValue: String {
        isSecret ? "••••••••" : value
    }

    public init(
        key: String,
        value: String = "",
        isSecret: Bool = false,
        keychainRef: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.isSecret = isSecret
        self.keychainRef = keychainRef
        self.detectedCategory = nil
        self.isMissing = false
        self.sortOrder = sortOrder
    }
}
