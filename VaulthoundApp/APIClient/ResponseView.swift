import SwiftUI
import VaulthoundModels

struct ResponseView: View {
    let response: APIResponse

    @State private var selectedTab = ResponseTab.body

    enum ResponseTab: String, CaseIterable {
        case body = "Body"
        case headers = "Headers"
        case timing = "Timing"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                statusBadge
                Spacer()

                Text("\(response.bodySize.formatted(.byteCount(style: .file)))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Text("\(String(format: "%.0f", response.timing.totalMs))ms")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            Picker("", selection: $selectedTab) {
                ForEach(ResponseTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            // Tab content
            switch selectedTab {
            case .body:
                bodyView
            case .headers:
                headersView
            case .timing:
                timingView
            }
        }
    }

    private var statusBadge: some View {
        Text("\(response.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: response.statusCode).capitalized)")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
            .accessibilityLabel("HTTP status \(response.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: response.statusCode).capitalized)")
    }

    private var sortedHeaders: [(key: String, value: String)] {
        response.responseHeaders.sorted { $0.key < $1.key }
    }

    private var statusColor: Color {
        switch response.statusCode {
        case 200..<300: return .green
        case 300..<400: return .yellow
        case 400..<500: return .orange
        case 500..<600: return .red
        default: return .secondary
        }
    }

    @ViewBuilder
    private var bodyView: some View {
        if let bodyString = response.bodyString {
            ScrollView {
                SyntaxHighlightedView(
                    content: bodyString,
                    contentType: response.bodyContentType
                )
                .padding()
                .textSelection(.enabled)
            }
        } else {
            ContentUnavailableView(
                "Binary Response",
                systemImage: "doc.fill",
                description: Text("\(response.bodySize.formatted(.byteCount(style: .file))) of binary data")
            )
        }
    }

    @ViewBuilder
    private var headersView: some View {
        List {
            ForEach(sortedHeaders, id: \.key) { key, value in
                HStack {
                    Text(key)
                        .font(.body.monospaced().bold())
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(value)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .contextMenu {
                    Button("Copy Value") {
                        ClipboardService.copy(value)
                    }
                    Button("Copy Header") {
                        ClipboardService.copy("\(key): \(value)")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(key): \(value)")
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var timingView: some View {
        Form {
            LabeledContent("Total") {
                Text("\(String(format: "%.1f", response.timing.totalMs))ms")
                    .font(.body.monospaced())
            }
            if response.timing.dnsMs > 0 {
                LabeledContent("DNS") {
                    Text("\(String(format: "%.1f", response.timing.dnsMs))ms")
                        .font(.body.monospaced())
                }
            }
            if response.timing.connectMs > 0 {
                LabeledContent("TCP Connect") {
                    Text("\(String(format: "%.1f", response.timing.connectMs))ms")
                        .font(.body.monospaced())
                }
            }
            if response.timing.tlsMs > 0 {
                LabeledContent("TLS") {
                    Text("\(String(format: "%.1f", response.timing.tlsMs))ms")
                        .font(.body.monospaced())
                }
            }
            if response.timing.ttfbMs > 0 {
                LabeledContent("Time to First Byte") {
                    Text("\(String(format: "%.1f", response.timing.ttfbMs))ms")
                        .font(.body.monospaced())
                }
            }
            if response.timing.transferMs > 0 {
                LabeledContent("Transfer") {
                    Text("\(String(format: "%.1f", response.timing.transferMs))ms")
                        .font(.body.monospaced())
                }
            }
        }
        .formStyle(.grouped)
    }
}
