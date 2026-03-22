import SwiftUI
import SwiftData
import VaulthoundModels

struct VariableDetailView: View {
    let environment: ProjectEnvironment

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var isSecretRevealed = false
    @State private var revealedValue: String?
    @State private var isAuthenticating = false

    private var selectedVariable: Variable? {
        if let id = appState.selectedVariableID {
            return environment.variables.first { $0.persistentModelID == id }
        }
        return environment.variables.min { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        if let variable = selectedVariable {
            Form {
                Section("Variable") {
                    LabeledContent("Key") {
                        Text(variable.key)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                    }

                    LabeledContent("Environment") {
                        Text(environment.name)
                    }

                    if let category = variable.detectedCategory {
                        LabeledContent("Provider") {
                            Text(categoryName(category))
                        }
                    }
                }

                Section("Value") {
                    if variable.isSecret {
                        HStack {
                            if isSecretRevealed, let value = revealedValue {
                                Text(value)
                                    .font(.body.monospaced())
                                    .textSelection(.enabled)
                            } else {
                                Text("••••••••")
                                    .font(.body.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                toggleReveal(variable)
                            } label: {
                                Image(systemName: isSecretRevealed ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .disabled(isAuthenticating)
                            .accessibilityLabel(isSecretRevealed ? "Hide secret" : "Reveal secret")
                            .accessibilityHint(isSecretRevealed ? "Hides the secret value" : "Authenticates and reveals the secret value")
                        }
                    } else {
                        TextField("Value", text: Binding(
                            get: { variable.value },
                            set: { variable.value = $0; variable.projectEnvironment?.updatedAt = .now }
                        ))
                        .font(.body.monospaced())
                        .textFieldStyle(.roundedBorder)
                    }
                }

                Section {
                    HStack {
                        Button("Copy Value") {
                            copyValue(variable)
                        }
                        .keyboardShortcut("c", modifiers: [.command, .shift])

                        Button("Copy Key") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(variable.key, forType: .string)
                        }
                    }

                    if variable.isSecret {
                        LabeledContent("Keychain Ref") {
                            Text(variable.keychainRef ?? "—")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }

                    if variable.isMissing {
                        Label("This variable is missing a value", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(variable.key)
        } else {
            ContentUnavailableView(
                "No Variable Selected",
                systemImage: "list.bullet",
                description: Text("Select a variable from the list.")
            )
        }
    }

    private func toggleReveal(_ variable: Variable) {
        if isSecretRevealed {
            isSecretRevealed = false
            revealedValue = nil
            return
        }

        isAuthenticating = true
        Task {
            defer { isAuthenticating = false }

            do {
                try await BiometricService.shared.authenticate()
                if let ref = variable.keychainRef {
                    revealedValue = try KeychainService.shared.read(account: ref)
                    isSecretRevealed = true

                    // Auto-hide after 30 seconds
                    Task {
                        try? await Task.sleep(for: .seconds(30))
                        isSecretRevealed = false
                        revealedValue = nil
                    }
                }
            } catch {
                // Authentication cancelled or failed
            }
        }
    }

    private func copyValue(_ variable: Variable) {
        if variable.isSecret, let ref = variable.keychainRef,
           let value = try? KeychainService.shared.read(account: ref) {
            ClipboardService.copy(value, isSecret: true)
        } else {
            ClipboardService.copy(variable.value)
        }
    }

    private func categoryName(_ category: SecretCategory) -> String {
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
        case .togetherAI: return "Together AI"
        case .groq: return "Groq"
        case .fireworks: return "Fireworks"
        case .generic: return "Generic"
        }
    }
}
