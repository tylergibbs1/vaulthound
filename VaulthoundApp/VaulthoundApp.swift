import SwiftUI
import SwiftData
import VaulthoundModels
import VaulthoundCore
import VaulthoundSecurity

@main
struct VaulthoundApp: App {
    let container: ModelContainer

    @State private var appState = AppState()
    @AppStorage("scanDirectories") private var scanDirectories = "~/Developer,~/Projects,~/Code"

    init() {
        let schema = Schema([
            Project.self,
            ProjectEnvironment.self,
            Variable.self,
            APIRequest.self,
            APIResponse.self,
            RequestCollection.self,
            CookieJar.self,
        ])

        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDir = appSupportURL.appending(path: "Vaulthound")
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        let storeURL = storeDir.appending(path: "vaulthound.store")
        let config = ModelConfiguration(url: storeURL)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environment(appState)
                .task {
                    await connectAndScan()
                }
        }
        .modelContainer(container)
        .defaultSize(width: 1100, height: 700)
        .commands {
            VaulthoundCommands(appState: appState)
        }

        MenuBarExtra("Vaulthound", systemImage: "key.fill") {
            MenuBarContentView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(container)

        Settings {
            SettingsView()
                .environment(appState)
        }
        .modelContainer(container)
    }

    @MainActor
    private func connectAndScan() async {
        // Seed example data on first launch
        SampleDataSeeder.seedIfNeeded(context: container.mainContext)

        // Connect to daemon — may not be running yet on first launch, which is fine.
        // The sample data gives users something to see immediately.
        let daemon = DaemonConnection.shared
        daemon.connect()

        let dirs = scanDirectories
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { ($0 as NSString).expandingTildeInPath }

        // Daemon scan is best-effort — app works without it via sample data
        let discovered = await daemon.scanProjects(in: dirs)
        guard !discovered.isEmpty else { return }

        let context = container.mainContext
        let existing = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        let existingPaths = Set(existing.map(\.path))

        for disc in discovered where !existingPaths.contains(disc.path) {
            let projectType = ProjectType(rawValue: disc.detectedType) ?? .unknown
            let project = Project(name: disc.name, path: disc.path, detectedType: projectType)
            project.lastScannedAt = .now
            context.insert(project)
        }

        try? context.save()
    }
}

// MARK: - App State

@Observable
@MainActor
final class AppState {
    var selectedProjectID: PersistentIdentifier?
    var selectedEnvironmentID: PersistentIdentifier?
    var selectedVariableID: PersistentIdentifier?
    var selectedRequestID: PersistentIdentifier?
    var sidebarMode: SidebarMode = .environments
    var isShowingImport = false
    var isShowingExport = false
    var isShowingNewProject = false
    var isShowingNewVariable = false
    var isShowingDiff = false
    var isShowingEnvironmentPicker = false
    var searchText = ""

    // Action triggers from keyboard shortcuts
    var sendRequestTrigger = false
    var duplicateRequestTrigger = false

    enum SidebarMode: String, CaseIterable {
        case environments = "Environments"
        case apiClient = "API Client"
    }
}

// MARK: - Commands

struct VaulthoundCommands: Commands {
    @Bindable var appState: AppState

    var body: some Commands {
        // MARK: New Item menu
        CommandGroup(after: .newItem) {
            Button("New Variable") {
                appState.isShowingNewVariable = true
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(appState.sidebarMode != .environments)

            Button("New Project") {
                appState.isShowingNewProject = true
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Divider()

            Button("Send Request") {
                appState.sendRequestTrigger.toggle()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(appState.sidebarMode != .apiClient)

            Button("Duplicate Request") {
                appState.duplicateRequestTrigger.toggle()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(appState.sidebarMode != .apiClient)
        }

        // MARK: View menu — sidebar and mode switching
        CommandGroup(after: .sidebar) {
            Button("Show Environments") {
                appState.sidebarMode = .environments
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Show API Client") {
                appState.sidebarMode = .apiClient
            }
            .keyboardShortcut("2", modifiers: .command)

            Divider()

            Button("Switch Environment") {
                appState.isShowingEnvironmentPicker = true
            }
            .keyboardShortcut("e", modifiers: .command)

            Button("Environment Diff") {
                appState.isShowingDiff = true
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }

        // MARK: Import/Export
        CommandGroup(after: .importExport) {
            Button("Import...") {
                appState.isShowingImport = true
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }
    }
}
