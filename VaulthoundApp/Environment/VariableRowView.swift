import SwiftUI
import VaulthoundModels

struct VariableRowView: View {
    let variable: Variable

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 11))
                .frame(width: 16)
                .accessibilityLabel(variable.isMissing ? "Missing value" : variable.isSecret ? "Secret" : "Plain variable")

            Text(variable.key)
                .font(.body.monospaced())
                .lineLimit(1)

            Spacer()

            Text(variable.displayValue)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 120, alignment: .trailing)

            if let category = variable.detectedCategory, category != .generic {
                Text(categoryLabel(category))
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(categoryColor(category).opacity(0.15))
                    .foregroundStyle(categoryColor(category))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .accessibilityLabel("Provider: \(categoryLabel(category))")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        if variable.isMissing {
            return "exclamationmark.triangle.fill"
        }
        if variable.isSecret {
            return "lock.fill"
        }
        return "textformat"
    }

    private var iconColor: Color {
        if variable.isMissing { return .yellow }
        if variable.isSecret { return .orange }
        return .secondary
    }

    private func categoryLabel(_ category: SecretCategory) -> String {
        switch category {
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .stripe: return "Stripe"
        case .aws: return "AWS"
        case .github: return "GitHub"
        case .google: return "Google"
        case .mistral: return "Mistral"
        case .cohere: return "Cohere"
        case .replicate: return "Replicate"
        case .huggingFace: return "HuggingFace"
        case .togetherAI: return "Together"
        case .groq: return "Groq"
        case .fireworks: return "Fireworks"
        case .generic: return ""
        }
    }

    private func categoryColor(_ category: SecretCategory) -> Color {
        switch category {
        case .openAI: return .green
        case .anthropic: return .orange
        case .stripe: return .purple
        case .aws: return .yellow
        case .github: return .primary
        case .google: return .blue
        default: return .secondary
        }
    }
}
