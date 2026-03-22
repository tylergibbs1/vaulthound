import SwiftUI
import SwiftData
import VaulthoundModels
import VaulthoundCore

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.name) private var projects: [Project]

    // Use appState.isShowingNewProject instead of local state

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selectedProjectID) {
            Section("Projects") {
                ForEach(projects) { project in
                    ProjectRowView(
                        name: project.name,
                        detectedType: project.detectedType,
                        activeEnvName: project.environments.first(where: { $0.isActive })?.name,
                        missingSecretCount: project.environments.reduce(0) { $0 + $1.variables.lazy.filter(\.isMissing).count }
                    )
                    .tag(project.persistentModelID)
                    .contextMenu {
                        projectContextMenu(for: project)
                    }
                }
            }

            if appState.sidebarMode == .apiClient {
                Section("Collections") {
                    if let project = selectedProject {
                        ForEach(sortedCollections(for: project)) { collection in
                            CollectionRowView(collection: collection)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    appState.isShowingNewProject = true
                } label: {
                    Label("New Project", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Spacer()
            }
        }
        // Sheet handled by MainWindow via appState.isShowingNewProject
    }

    private var selectedProject: Project? {
        guard let id = appState.selectedProjectID else { return projects.first }
        return projects.first { $0.persistentModelID == id }
    }

    private func sortedCollections(for project: Project) -> [RequestCollection] {
        project.collections.sorted { $0.sortOrder < $1.sortOrder }
    }

    @ViewBuilder
    private func projectContextMenu(for project: Project) -> some View {
        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path)
        }
        Button("Add Environment...") {
            addEnvironment(to: project)
        }
        Divider()
        Button("Delete Project", role: .destructive) {
            modelContext.delete(project)
        }
    }

    private func addEnvironment(to project: Project) {
        let env = ProjectEnvironment(name: "new-environment", project: project)
        modelContext.insert(env)
    }
}

// MARK: - New Project Sheet

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var path = ""
    @FocusState private var focusedField: Field?

    enum Field: Hashable { case name, path }

    var body: some View {
        Form {
            TextField("Project Name", text: $name)
                .focused($focusedField, equals: .name)
            HStack {
                TextField("Path", text: $path)
                    .focused($focusedField, equals: .path)
                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK, let url = panel.url {
                        path = url.path
                        if name.isEmpty {
                            name = url.lastPathComponent
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 400)
        .onAppear { focusedField = .name }
        .onSubmit { if focusedField == .name { focusedField = .path } }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    let project = Project(name: name, path: path)
                    project.detectedType = detectProjectType(at: path)
                    modelContext.insert(project)

                    // Auto-detect and import .env files
                    let envFiles = scanForEnvFiles(at: path)
                    if envFiles.isEmpty {
                        let defaultEnv = ProjectEnvironment(name: "local", project: project)
                        defaultEnv.isActive = true
                        modelContext.insert(defaultEnv)
                    } else {
                        importEnvFiles(envFiles, into: project)
                    }

                    // Auto-discover API routes from framework conventions
                    discoverRoutes(at: path, into: project)

                    dismiss()
                }
                .disabled(name.isEmpty || path.isEmpty)
            }
        }
    }

    // MARK: - Auto-detection

    private func detectProjectType(at path: String) -> ProjectType {
        let fm = FileManager.default
        let markers: [(String, ProjectType)] = [
            ("Package.swift", .swift), ("package.json", .node),
            ("Cargo.toml", .rust), ("pyproject.toml", .python),
            ("go.mod", .go), ("Gemfile", .ruby), ("pom.xml", .java),
        ]
        for (file, type) in markers {
            if fm.fileExists(atPath: URL(filePath: path).appending(path: file).path) {
                return type
            }
        }
        // Check for .xcodeproj
        if let contents = try? fm.contentsOfDirectory(atPath: path),
           contents.contains(where: { $0.hasSuffix(".xcodeproj") }) {
            return .swift
        }
        return .unknown
    }

    private func scanForEnvFiles(at path: String) -> [(name: String, url: URL)] {
        let dir = URL(filePath: path)
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [] }

        let envPatterns = [".env", ".env.local", ".env.development", ".env.staging",
                           ".env.production", ".env.example", ".env.test"]

        return contents
            .filter { name in name == ".env" || name.hasPrefix(".env.") }
            .sorted()
            .map { (name: $0, url: dir.appending(path: $0)) }
    }

    private func importEnvFiles(_ files: [(name: String, url: URL)], into project: Project) {
        let codec = EnvFileCodec()
        let detector = SecretDetector()
        var isFirst = true

        for file in files {
            // Derive environment name: .env → "local", .env.staging → "staging"
            let envName: String
            if file.name == ".env" {
                envName = "local"
            } else {
                envName = String(file.name.dropFirst(5)) // drop ".env."
            }

            // Skip .env.example — we'll use it for missing-value detection
            if envName == "example" { continue }

            let env = ProjectEnvironment(name: envName, project: project)
            env.isActive = isFirst
            env.sourceFilePath = file.url.path
            env.isWatching = true
            modelContext.insert(env)
            isFirst = false

            guard let content = try? String(contentsOf: file.url, encoding: .utf8) else { continue }
            let parsed = codec.parseVariables(content)

            for (index, pair) in parsed.enumerated() {
                let isSecret = detector.isLikelySecret(key: pair.key, value: pair.value)
                let category = detector.detect(key: pair.key, value: pair.value)

                let variable = Variable(
                    key: pair.key,
                    value: isSecret ? "" : pair.value,
                    isSecret: isSecret,
                    sortOrder: index
                )
                variable.detectedCategory = category
                variable.projectEnvironment = env
                modelContext.insert(variable)

                if isSecret && !pair.value.isEmpty {
                    let account = KeychainAccount.make(
                        projectID: project.id.uuidString,
                        envName: envName,
                        variableKey: pair.key
                    )
                    variable.keychainRef = account
                    try? KeychainService.shared.save(account: account, value: pair.value)
                } else if isSecret {
                    variable.isMissing = true
                }
            }
        }

        // Check .env.example for missing variables
        if let exampleFile = files.first(where: { $0.name == ".env.example" }),
           let exampleContent = try? String(contentsOf: exampleFile.url, encoding: .utf8) {
            let exampleVars = Set(codec.parseVariables(exampleContent).map(\.key))

            for env in project.environments {
                let existingKeys = Set(env.variables.map(\.key))
                let missing = exampleVars.subtracting(existingKeys)
                for key in missing {
                    let variable = Variable(key: key, sortOrder: env.variables.count)
                    variable.isMissing = true
                    variable.projectEnvironment = env
                    modelContext.insert(variable)
                }
            }
        }
    }

    // MARK: - Route Discovery

    private func discoverRoutes(at path: String, into project: Project) {
        let discovery = RouteDiscovery()
        let routes = discovery.discover(at: path)
        guard !routes.isEmpty else { return }

        // Group routes by framework for collection naming
        let grouped = Dictionary(grouping: routes, by: { $0.framework.rawValue })

        for (frameworkName, frameworkRoutes) in grouped {
            let collection = RequestCollection(
                name: "\(frameworkName) Routes",
                project: project,
                sortOrder: project.collections.count
            )
            modelContext.insert(collection)

            for (index, route) in frameworkRoutes.enumerated() {
                // Create one request per method per route
                for method in route.methods {
                    let routeName = "\(method.rawValue) \(route.path)"
                    let request = APIRequest(
                        name: routeName,
                        method: method,
                        urlTemplate: "{{BASE_URL}}\(route.path)",
                        headers: defaultHeaders(for: method),
                        bodyType: method == .POST || method == .PUT || method == .PATCH ? .json : .none,
                        sortOrder: index * route.methods.count + (route.methods.firstIndex(of: method) ?? 0)
                    )
                    if request.bodyType == .json {
                        request.bodyContent = "{\n  \n}"
                    }
                    request.collection = collection
                    modelContext.insert(request)
                }
            }
        }
    }

    private func defaultHeaders(for method: HTTPMethod) -> [RequestHeader] {
        var headers = [RequestHeader(key: "Accept", value: "application/json")]
        if method == .POST || method == .PUT || method == .PATCH {
            headers.append(RequestHeader(key: "Content-Type", value: "application/json"))
        }
        return headers
    }
}
