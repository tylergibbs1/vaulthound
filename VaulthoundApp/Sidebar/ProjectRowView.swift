import SwiftUI
import VaulthoundModels

/// POD-friendly row: passes only the values needed for display.
struct ProjectRowView: View {
    let name: String
    let detectedType: ProjectType
    let activeEnvName: String?
    let missingSecretCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .foregroundStyle(missingSecretCount > 0 ? .yellow : .green)
                .font(.system(size: 12))
                .accessibilityLabel("\(detectedType == .unknown ? "Generic" : String(describing: detectedType).capitalized) project")

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.body)
                    .lineLimit(1)

                if let activeEnvName {
                    Text(activeEnvName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if missingSecretCount > 0 {
                Text("\(missingSecretCount)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.yellow.opacity(0.2))
                    .clipShape(Capsule())
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("\(missingSecretCount) missing secret\(missingSecretCount == 1 ? "" : "s")")
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch detectedType {
        case .swift: return "swift"
        case .node: return "curlybraces"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .rust: return "gearshape.2"
        case .go: return "arrow.right.circle"
        case .ruby: return "diamond"
        case .java: return "cup.and.saucer"
        case .unknown: return "folder.fill"
        }
    }
}
