import SwiftUI
import SwiftData
import VaulthoundModels

struct StatusBarView: View {
    @Query(sort: \Project.name) private var projects: [Project]
    @ObservedObject private var daemon = DaemonConnection.shared

    var body: some View {
        HStack(spacing: 12) {
            ActiveProjectLabel(projects: projects)

            Spacer()

            MissingSecretsLabel(projects: projects)

            DaemonStatusLabel(state: daemon.state)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

// MARK: - Extracted subviews for isolated invalidation

/// Only redraws when the active project changes.
private struct ActiveProjectLabel: View {
    let projects: [Project]

    var body: some View {
        if let active = projects.first(where: { $0.isActive }) {
            Group {
                Label(active.name, systemImage: "folder.fill")
                    .font(.caption)

                if let env = active.environments.first(where: { $0.isActive }) {
                    Text("·")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(env.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Active project: \(active.name)\(active.environments.first(where: { $0.isActive }).map { ", environment: \($0.name)" } ?? "")")
        }
    }
}

/// Isolated so the expensive count doesn't re-run when daemon status changes.
private struct MissingSecretsLabel: View {
    let projects: [Project]

    private var missingCount: Int {
        projects.reduce(0) { total, project in
            total + project.environments.reduce(0) { envTotal, env in
                envTotal + env.variables.lazy.filter(\.isMissing).count
            }
        }
    }

    var body: some View {
        if missingCount > 0 {
            Label("\(missingCount) missing", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)
                .accessibilityLabel("\(missingCount) missing secret\(missingCount == 1 ? "" : "s")")
        }
    }
}

/// POD view — shows daemon connection state without alarming users.
private struct DaemonStatusLabel: View {
    let state: DaemonConnection.ConnectionState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(label)")
    }

    private var dotColor: Color {
        switch state {
        case .connected: return .green
        case .unavailable: return .blue
        case .disconnected: return .orange
        case .idle: return .secondary
        }
    }

    private var label: String {
        switch state {
        case .connected: return "daemon running"
        case .unavailable: return "local mode"
        case .disconnected: return "daemon disconnected"
        case .idle: return "starting..."
        }
    }
}
