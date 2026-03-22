import SwiftUI
import SwiftData
import VaulthoundModels
import VaulthoundCore

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.name) private var projects: [Project]

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } content: {
            contentColumn
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 400)
        } detail: {
            detailColumn
        }
        .searchable(text: $appState.searchText, prompt: "Search")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarItems
            }
        }
        .overlay(alignment: .bottom) {
            StatusBarView()
        }
        .onChange(of: projects.count) { _, _ in
            if appState.selectedProjectID == nil, let first = projects.first {
                appState.selectedProjectID = first.persistentModelID
            }
        }
        .onAppear {
            if appState.selectedProjectID == nil, let first = projects.first {
                appState.selectedProjectID = first.persistentModelID
            }
        }
        .sheet(isPresented: $appState.isShowingImport) {
            if let project = selectedProject {
                ImportSheet(project: project)
            }
        }
        .sheet(isPresented: $appState.isShowingNewProject) {
            NewProjectSheet()
        }
        .sheet(isPresented: $appState.isShowingNewVariable) {
            if let env = selectedEnvironment {
                AddVariableSheet(environment: env)
            }
        }
        .sheet(isPresented: $appState.isShowingDiff) {
            if let project = selectedProject {
                EnvironmentDiffPicker(project: project)
            }
        }
        .sheet(isPresented: $appState.isShowingEnvironmentPicker) {
            if let project = selectedProject {
                EnvironmentPickerSheet(project: project) { env in
                    selectEnvironment(env)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if let project = selectedProject {
            switch appState.sidebarMode {
            case .environments:
                EnvironmentEditorView(project: project)
            case .apiClient:
                RequestListView(project: project)
            }
        } else {
            ContentUnavailableView(
                "No Project Selected",
                systemImage: "folder",
                description: Text("Select a project from the sidebar or create a new one.")
            )
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let project = selectedProject {
            switch appState.sidebarMode {
            case .environments:
                if let env = selectedEnvironment {
                    VariableDetailView(environment: env)
                } else {
                    ContentUnavailableView(
                        "No Variable Selected",
                        systemImage: "list.bullet",
                        description: Text("Select a variable to view its details.")
                    )
                }
            case .apiClient:
                RequestBuilderView(project: project)
            }
        } else {
            ContentUnavailableView(
                "Welcome to Vaulthound",
                systemImage: "key.fill",
                description: Text("The environment layer for macOS developers.")
            )
        }
    }

    @ViewBuilder
    private var toolbarItems: some View {
        Picker("Mode", selection: Bindable(appState).sidebarMode) {
            ForEach(AppState.SidebarMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)

        if appState.sidebarMode == .environments {
            Menu {
                if let project = selectedProject {
                    ForEach(project.environments) { env in
                        Button {
                            selectEnvironment(env)
                        } label: {
                            HStack {
                                Text(env.name)
                                if env.isActive {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                Label(selectedEnvironment?.name ?? "Environment", systemImage: "server.rack")
            }
        }

        Button {
            appState.isShowingImport = true
        } label: {
            Label("Import", systemImage: "square.and.arrow.down")
        }
    }

    private var selectedProject: Project? {
        guard let id = appState.selectedProjectID else {
            return projects.first
        }
        return projects.first { $0.persistentModelID == id }
    }

    private var selectedEnvironment: ProjectEnvironment? {
        guard let project = selectedProject else { return nil }
        if let id = appState.selectedEnvironmentID {
            return project.environments.first { $0.persistentModelID == id }
        }
        return project.environments.first { $0.isActive } ?? project.environments.first
    }

    private func selectEnvironment(_ env: ProjectEnvironment) {
        if let project = selectedProject {
            for e in project.environments {
                e.isActive = false
            }
        }
        env.isActive = true
        appState.selectedEnvironmentID = env.persistentModelID
    }

    // MARK: - Drag and Drop

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.lastPathComponent.contains(".env") else { return }

                Task { @MainActor in
                    guard let env = self.selectedEnvironment else { return }
                    self.importEnvFromDrop(url, into: env)
                }
            }
        }
        return true
    }

    private func importEnvFromDrop(_ url: URL, into env: ProjectEnvironment) {
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
}

// MARK: - Environment Diff Picker (⌘⇧D)

struct EnvironmentDiffPicker: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var leftEnvID: PersistentIdentifier?
    @State private var rightEnvID: PersistentIdentifier?

    var body: some View {
        VStack(spacing: 16) {
            Text("Compare Environments")
                .font(.headline)

            HStack(spacing: 16) {
                Picker("Left", selection: $leftEnvID) {
                    Text("Select...").tag(nil as PersistentIdentifier?)
                    ForEach(project.environments) { env in
                        Text(env.name).tag(env.persistentModelID as PersistentIdentifier?)
                    }
                }

                Image(systemName: "arrow.left.arrow.right")

                Picker("Right", selection: $rightEnvID) {
                    Text("Select...").tag(nil as PersistentIdentifier?)
                    ForEach(project.environments) { env in
                        Text(env.name).tag(env.persistentModelID as PersistentIdentifier?)
                    }
                }
            }

            if let leftID = leftEnvID, let rightID = rightEnvID,
               let left = project.environments.first(where: { $0.persistentModelID == leftID }),
               let right = project.environments.first(where: { $0.persistentModelID == rightID }) {
                EnvDiffView(leftEnv: left, rightEnv: right)
                    .frame(minHeight: 300)
            }

            Button("Done") { dismiss() }
        }
        .padding()
        .frame(width: 700, height: 500)
    }
}

// MARK: - Environment Picker Sheet (⌘E)

struct EnvironmentPickerSheet: View {
    let project: Project
    let onSelect: (ProjectEnvironment) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Switch Environment")
                .font(.headline)

            List(project.environments) { env in
                Button {
                    onSelect(env)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: env.isActive ? "circle.fill" : "circle")
                            .foregroundStyle(env.isActive ? .green : .secondary)
                            .font(.system(size: 10))
                        Text(env.name)
                            .font(.body)
                        Spacer()
                        Text("\(env.variables.count) vars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 150)
        }
        .padding()
        .frame(width: 300, height: 250)
    }
}
