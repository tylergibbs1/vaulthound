import SwiftUI
import VaulthoundModels

struct RequestHistoryView: View {
    let request: APIRequest

    private var sortedHistory: [APIResponse] {
        request.responseHistory.sorted { $0.receivedAt > $1.receivedAt }
    }

    var body: some View {
        List(sortedHistory) { response in
            HStack {
                statusBadge(response.statusCode)

                Text(response.requestSnapshot.url)
                    .font(.caption.monospaced())
                    .lineLimit(1)

                Spacer()

                Text("\(String(format: "%.0f", response.timing.totalMs))ms")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Text(response.receivedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
    }

    private func statusBadge(_ code: Int) -> some View {
        Text("\(code)")
            .font(.caption.monospaced().bold())
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(statusColor(code).opacity(0.15))
            .foregroundStyle(statusColor(code))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityLabel("HTTP status \(code)")
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .yellow
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .secondary
        }
    }
}
