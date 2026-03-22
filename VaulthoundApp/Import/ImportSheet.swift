import SwiftUI
import SwiftData
import VaulthoundModels

struct ImportSheet: View {
    let project: Project

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var importType: ImportType = .postman
    @State private var curlText = ""
    @State private var errorMessage: String?

    enum ImportType: String, CaseIterable {
        case postman = "Postman Collection"
        case curl = "cURL Command"
        case envFile = ".env File"
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Import Type", selection: $importType) {
                ForEach(ImportType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            switch importType {
            case .postman:
                postmanImport
            case .curl:
                curlImport
            case .envFile:
                envImport
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 500, height: 300)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var postmanImport: some View {
        VStack(spacing: 12) {
            Text("Select a Postman Collection v2.1 JSON file")
                .foregroundStyle(.secondary)

            Button("Choose File...") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.json]
                panel.canChooseDirectories = false

                if panel.runModal() == .OK, let url = panel.url {
                    let importer = PostmanImporter(modelContext: modelContext)
                    do {
                        try importer.importCollection(from: url, into: project)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var curlImport: some View {
        VStack(spacing: 12) {
            Text("Paste a cURL command")
                .foregroundStyle(.secondary)

            TextEditor(text: $curlText)
                .font(.body.monospaced())
                .frame(minHeight: 150)
                .border(Color.secondary.opacity(0.3))

            Button("Import") {
                let collection: RequestCollection
                if let existing = project.collections.first {
                    collection = existing
                } else {
                    collection = RequestCollection(name: "Imported", project: project)
                    modelContext.insert(collection)
                }

                let importer = CurlImporter(modelContext: modelContext)
                do {
                    try importer.importCurl(curlText, into: collection)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .disabled(curlText.isEmpty)
        }
    }

    @ViewBuilder
    private var envImport: some View {
        VStack(spacing: 12) {
            Text("Select a .env file to import variables")
                .foregroundStyle(.secondary)

            Button("Choose .env File...") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = false
                panel.allowedContentTypes = [.plainText]

                if panel.runModal() == .OK, let _ = panel.url {
                    // Handled by EnvironmentEditorView's file importer
                    dismiss()
                }
            }
        }
    }
}
