import SwiftUI
import SwiftData
import VaulthoundModels
import VaulthoundCore

struct EnvironmentEditorView: View {
    let project: Project

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingAddVariable = false
    @State private var isShowingEnvImport = false

    private var activeEnvironment: ProjectEnvironment? {
        if let id = appState.selectedEnvironmentID {
            return project.environments.first { $0.persistentModelID == id }
        }
        return project.environments.first { $0.isActive } ?? project.environments.first
    }

    private var filteredVariables: [Variable] {
        guard let env = activeEnvironment else { return [] }
        let sorted = env.variables.sorted { $0.sortOrder < $1.sortOrder }
        if appState.searchText.isEmpty { return sorted }
        return sorted.filter {
            $0.key.localizedCaseInsensitiveContains(appState.searchText) ||
            $0.value.localizedCaseInsensitiveContains(appState.searchText)
        }
    }

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selectedVariableID) {
            if let env = activeEnvironment {
                Section {
                    ForEach(filteredVariables) { variable in
                        VariableRowView(variable: variable)
                            .tag(variable.persistentModelID)
                            .contextMenu {
                                variableContextMenu(for: variable, in: env)
                            }
                    }
                    .onMove { from, to in
                        reorderVariables(from: from, to: to, in: env)
                    }
                } header: {
                    HStack {
                        Text("\(env.name)")
                            .textCase(.uppercase)
                            .font(.caption.bold())
                        Spacer()
                        Text("\(filteredVariables.count) vars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    isShowingAddVariable = true
                } label: {
                    Label("Add Variable", systemImage: "plus")
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    isShowingEnvImport = true
                } label: {
                    Label("Import .env", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .sheet(isPresented: $isShowingAddVariable) {
            AddVariableSheet(environment: activeEnvironment)
        }
        .fileImporter(isPresented: $isShowingEnvImport, allowedContentTypes: [.plainText]) { result in
            if case .success(let url) = result, let env = activeEnvironment {
                importEnvFile(url, into: env)
            }
        }
    }

    @ViewBuilder
    private func variableContextMenu(for variable: Variable, in env: ProjectEnvironment) -> some View {
        Button("Copy Value") {
            ClipboardService.copy(variable.isSecret ? "••••••••" : variable.value, isSecret: variable.isSecret)
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])

        Button("Copy Key") {
            ClipboardService.copy(variable.key)
        }

        if variable.isSecret {
            Button("Reveal Secret") {
                appState.selectedVariableID = variable.persistentModelID
            }
        }

        Divider()

        Button("Delete", role: .destructive) {
            modelContext.delete(variable)
        }
    }

    private func importEnvFile(_ url: URL, into env: ProjectEnvironment) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        let codec = EnvFileCodec()
        let detector = SecretDetector()
        let parsed = codec.parseVariables(content)

        for (index, pair) in parsed.enumerated() {
            let isSecret = detector.isLikelySecret(key: pair.key, value: pair.value)
            let category = detector.detect(key: pair.key, value: pair.value)

            let variable = Variable(
                key: pair.key,
                value: isSecret ? "" : pair.value,
                isSecret: isSecret,
                sortOrder: env.variables.count + index
            )
            variable.detectedCategory = category
            variable.projectEnvironment = env
            modelContext.insert(variable)

            if isSecret {
                let account = KeychainAccount.make(
                    projectID: env.project?.id.uuidString ?? "",
                    envName: env.name,
                    variableKey: pair.key
                )
                variable.keychainRef = account
                try? KeychainService.shared.save(account: account, value: pair.value)
            }
        }

        env.sourceFilePath = url.path
        env.updatedAt = .now
    }

    private func reorderVariables(from source: IndexSet, to destination: Int, in env: ProjectEnvironment) {
        var vars = env.variables.sorted { $0.sortOrder < $1.sortOrder }
        vars.move(fromOffsets: source, toOffset: destination)
        for (index, v) in vars.enumerated() {
            v.sortOrder = index
        }
    }
}

enum KeychainAccount {
    static func make(projectID: String, envName: String, variableKey: String) -> String {
        "\(projectID)/\(envName)/\(variableKey)"
    }
}

// MARK: - Add Variable Sheet

struct AddVariableSheet: View {
    let environment: ProjectEnvironment?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var key = ""
    @State private var value = ""
    @State private var isSecret = false
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case key, value }

    var body: some View {
        Form {
            TextField("Key", text: $key)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .key)

            TextField("Value", text: $value)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .value)

            Toggle("Secret (store in Keychain)", isOn: $isSecret)
        }
        .padding()
        .frame(width: 350)
        .onAppear { focusedField = .key }
        .onSubmit { if focusedField == .key { focusedField = .value } }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    guard let env = environment else { return }
                    let variable = Variable(
                        key: key.uppercased(),
                        value: isSecret ? "" : value,
                        isSecret: isSecret,
                        sortOrder: env.variables.count
                    )
                    variable.projectEnvironment = env
                    modelContext.insert(variable)

                    if isSecret {
                        let account = KeychainAccount.make(
                            projectID: env.project?.id.uuidString ?? "",
                            envName: env.name,
                            variableKey: key.uppercased()
                        )
                        variable.keychainRef = account
                        try? KeychainService.shared.save(account: account, value: value)
                    }

                    let detector = SecretDetector()
                    variable.detectedCategory = detector.detect(key: key, value: value)

                    dismiss()
                }
                .disabled(key.isEmpty)
            }
        }
    }
}
