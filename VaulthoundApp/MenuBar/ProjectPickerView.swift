import SwiftUI
import VaulthoundModels

struct ProjectPickerView: View {
    let projects: [Project]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(projects) { project in
                    ProjectMenuRow(
                        name: project.name,
                        isActive: project.isActive,
                        activeEnvName: project.environments.first(where: { $0.isActive })?.name,
                        hasMissingSecrets: project.environments.contains { env in
                            env.variables.contains(where: \.isMissing)
                        },
                        onActivate: { project.isActive = true }
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 200)
    }
}

/// POD view — only scalar values, fast memcmp diffing.
private struct ProjectMenuRow: View {
    let name: String
    let isActive: Bool
    let activeEnvName: String?
    let hasMissingSecrets: Bool
    let onActivate: () -> Void

    var body: some View {
        Button(action: onActivate) {
            HStack(spacing: 8) {
                Image(systemName: isActive ? "circle.fill" : "circle")
                    .font(.system(size: 8))
                    .foregroundStyle(isActive ? .green : .secondary)
                    .accessibilityLabel(isActive ? "Active" : "Inactive")

                Text(name)
                    .font(.body)

                if let activeEnvName {
                    Text("· \(activeEnvName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if hasMissingSecrets {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .accessibilityLabel("Has missing secrets")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name)\(activeEnvName.map { ", \($0)" } ?? "")\(isActive ? ", active" : "")\(hasMissingSecrets ? ", has missing secrets" : "")")
        .accessibilityHint("Activate this project")
    }
}
