import SwiftUI
import VaulthoundModels

struct ExportSheet: View {
    let request: APIRequest
    let variables: [String: String]

    @Environment(\.dismiss) private var dismiss

    @State private var exportFormat: ExportFormat = .curl
    @State private var exportedCode = ""

    enum ExportFormat: String, CaseIterable {
        case curl = "cURL"
        case swift = "Swift URLSession"
        case python = "Python requests"
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Format", selection: $exportFormat) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: exportFormat) { _, _ in
                regenerateExport()
            }

            ScrollView {
                Text(exportedCode)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(exportedCode, forType: .string)
                }

                Spacer()

                Button("Done") { dismiss() }
            }
        }
        .padding()
        .frame(width: 600, height: 400)
        .onAppear { regenerateExport() }
    }

    private func regenerateExport() {
        switch exportFormat {
        case .curl:
            exportedCode = CurlExporter.export(request, variables: variables)
        case .swift:
            exportedCode = SwiftExporter.export(request, variables: variables)
        case .python:
            exportedCode = PythonExporter.export(request, variables: variables)
        }
    }
}
