import SwiftUI
import SwiftData
import VaulthoundModels

struct CollectionRowView: View {
    let collection: RequestCollection

    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded = true
    @State private var isRenaming = false
    @State private var newName = ""

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(sortedRequests) { request in
                HStack(spacing: 6) {
                    Text(request.method.rawValue)
                        .font(.caption.monospaced().bold())
                        .foregroundStyle(methodColor(request.method))
                        .frame(width: 40, alignment: .leading)
                        .accessibilityLabel("HTTP \(request.method.rawValue)")

                    Text(request.name)
                        .font(.body)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
                .accessibilityElement(children: .combine)
                .contextMenu {
                    Button("Duplicate") {
                        let dupe = APIRequest(
                            name: "\(request.name) (copy)",
                            method: request.method,
                            urlTemplate: request.urlTemplate,
                            headers: request.headers,
                            bodyType: request.bodyType,
                            sortOrder: collection.requests.count
                        )
                        dupe.bodyContent = request.bodyContent
                        dupe.collection = collection
                        modelContext.insert(dupe)
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        modelContext.delete(request)
                    }
                }
            }
        } label: {
            Label(collection.name, systemImage: "folder")
        }
        .contextMenu {
            Button("Rename...") {
                newName = collection.name
                isRenaming = true
            }

            Button("Add Request") {
                let request = APIRequest(
                    name: "New Request",
                    sortOrder: collection.requests.count
                )
                request.collection = collection
                modelContext.insert(request)
            }

            Divider()

            Button("Delete Collection", role: .destructive) {
                modelContext.delete(collection)
            }
        }
        .alert("Rename Collection", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                collection.name = newName
            }
        }
    }

    private var sortedRequests: [APIRequest] {
        collection.requests.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func methodColor(_ method: HTTPMethod) -> Color {
        switch method {
        case .GET: return .blue
        case .POST: return .green
        case .PUT: return .orange
        case .PATCH: return .yellow
        case .DELETE: return .red
        case .HEAD: return .purple
        case .OPTIONS: return .gray
        }
    }
}
