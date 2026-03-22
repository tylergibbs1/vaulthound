import SwiftUI
import VaulthoundModels

struct EnvDiffView: View {
    let leftEnv: ProjectEnvironment
    let rightEnv: ProjectEnvironment

    var body: some View {
        let diff = computeDiff()

        Table(diff) {
            TableColumn("Key") { row in
                Text(row.key)
                    .font(.body.monospaced())
            }

            TableColumn(leftEnv.name) { row in
                Text(row.leftValue ?? "—")
                    .font(.body.monospaced())
                    .foregroundStyle(row.status == .onlyLeft || row.status == .different ? .primary : .secondary)
            }

            TableColumn(rightEnv.name) { row in
                Text(row.rightValue ?? "—")
                    .font(.body.monospaced())
                    .foregroundStyle(row.status == .onlyRight || row.status == .different ? .primary : .secondary)
            }

            TableColumn("Status") { row in
                statusBadge(row.status)
            }
            .width(80)
        }
        .navigationTitle("Diff: \(leftEnv.name) vs \(rightEnv.name)")
        .toolbar {
            ToolbarItem {
                Button("Export as Markdown") {
                    exportMarkdown(diff)
                }
            }
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: DiffStatus) -> some View {
        Text(status.label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.15))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
    }

    private func computeDiff() -> [DiffRow] {
        let leftVars = Dictionary(uniqueKeysWithValues: leftEnv.variables.map { ($0.key, $0) })
        let rightVars = Dictionary(uniqueKeysWithValues: rightEnv.variables.map { ($0.key, $0) })
        let allKeys = Set(leftVars.keys).union(rightVars.keys).sorted()

        return allKeys.map { key in
            let left = leftVars[key]
            let right = rightVars[key]

            let leftVal = left?.displayValue
            let rightVal = right?.displayValue

            let status: DiffStatus
            if left == nil { status = .onlyRight }
            else if right == nil { status = .onlyLeft }
            else if leftVal == rightVal { status = .same }
            else { status = .different }

            return DiffRow(key: key, leftValue: leftVal, rightValue: rightVal, status: status)
        }
    }

    private func exportMarkdown(_ diff: [DiffRow]) {
        var md = "# Environment Diff: \(leftEnv.name) vs \(rightEnv.name)\n\n"
        md += "| Key | \(leftEnv.name) | \(rightEnv.name) | Status |\n"
        md += "|-----|-------|--------|--------|\n"

        for row in diff {
            md += "| `\(row.key)` | \(row.leftValue ?? "—") | \(row.rightValue ?? "—") | \(row.status.label) |\n"
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
    }
}

struct DiffRow: Identifiable {
    let id = UUID()
    let key: String
    let leftValue: String?
    let rightValue: String?
    let status: DiffStatus
}

enum DiffStatus {
    case same, different, onlyLeft, onlyRight

    var label: String {
        switch self {
        case .same: return "Same"
        case .different: return "Changed"
        case .onlyLeft: return "Left only"
        case .onlyRight: return "Right only"
        }
    }

    var color: Color {
        switch self {
        case .same: return .secondary
        case .different: return .orange
        case .onlyLeft: return .red
        case .onlyRight: return .green
        }
    }
}
