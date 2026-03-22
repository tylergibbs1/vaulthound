import SwiftUI
import VaulthoundModels

struct EnvironmentSwitcherView: View {
    let project: Project
    let activeEnv: ProjectEnvironment

    var body: some View {
        HStack(spacing: 4) {
            Text("Switch:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(project.environments) { env in
                Button {
                    switchTo(env)
                } label: {
                    Text(env.name)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(env.id == activeEnv.id ? Color.accentColor.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func switchTo(_ env: ProjectEnvironment) {
        for e in project.environments {
            e.isActive = false
        }
        env.isActive = true
    }
}
