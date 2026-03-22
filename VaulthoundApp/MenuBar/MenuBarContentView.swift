import SwiftUI
import SwiftData
import VaulthoundModels

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Project.name) private var projects: [Project]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Active project header
            if let activeProject = projects.first(where: { $0.isActive }) {
                activeProjectHeader(activeProject)
                Divider()

                // Quick copy variables
                QuickCopyView(project: activeProject)
                Divider()
            }

            // Project list
            ProjectPickerView(projects: projects)

            Divider()

            // Status
            statusSection

            Divider()

            // Actions
            HStack {
                Button("Open Vaulthound") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(12)
        }
        .frame(width: 300)
    }

    @ViewBuilder
    private func activeProjectHeader(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text(project.name)
                    .font(.headline)

                if let env = project.environments.first(where: { $0.isActive }) {
                    Text("· \(env.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Active project: \(project.name)\(project.environments.first(where: { $0.isActive }).map { ", environment: \($0.name)" } ?? "")")

            if let activeEnv = project.environments.first(where: { $0.isActive }) {
                EnvironmentSwitcherView(project: project, activeEnv: activeEnv)
            }
        }
        .padding(12)
    }

    private var totalMissingCount: Int {
        projects.reduce(0) { total, project in
            total + project.environments.reduce(0) { $0 + $1.variables.lazy.filter(\.isMissing).count }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if totalMissingCount > 0 {
                Label("\(totalMissingCount) missing secrets", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            } else {
                Label("All secrets configured", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            Label("\(projects.count) projects", systemImage: "folder")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }
}

// MARK: - Quick Copy View

struct QuickCopyView: View {
    let project: Project

    @State private var copiedKey: String?

    private var activeEnv: ProjectEnvironment? {
        project.environments.first(where: { $0.isActive }) ?? project.environments.first
    }

    var body: some View {
        if let env = activeEnv {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(topVariables(from: env)) { variable in
                        Button {
                            copyVariable(variable)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: variable.isSecret ? "lock.fill" : "doc.on.clipboard")
                                    .font(.system(size: 10))
                                    .foregroundStyle(variable.isSecret ? .orange : .secondary)
                                    .frame(width: 14)
                                    .accessibilityLabel(variable.isSecret ? "Secret" : "Variable")

                                Text(variable.key)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)

                                Spacer()

                                if copiedKey == variable.key {
                                    Text("Copied")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                        .accessibilityLabel("Copied to clipboard")
                                } else {
                                    Text(variable.displayValue)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .frame(maxWidth: 80, alignment: .trailing)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 3)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copy \(variable.key)")
                        .accessibilityHint(variable.isSecret ? "Copies secret value to clipboard" : "Copies value to clipboard")
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 180)
        }
    }

    private func topVariables(from env: ProjectEnvironment) -> [Variable] {
        Array(env.variables.sorted { $0.sortOrder < $1.sortOrder }.prefix(10))
    }

    private func copyVariable(_ variable: Variable) {
        if variable.isSecret, let ref = variable.keychainRef,
           let value = try? KeychainService.shared.read(account: ref) {
            ClipboardService.copy(value, isSecret: true)
        } else {
            ClipboardService.copy(variable.value)
        }

        copiedKey = variable.key
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedKey == variable.key {
                copiedKey = nil
            }
        }
    }
}
