import Foundation
import SwiftData
import VaulthoundModels
import VaulthoundCore

@MainActor
struct PostmanImporter {
    let modelContext: ModelContext

    func importCollection(from url: URL, into project: Project) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        let parser = PostmanV21Parser()
        let parsed = try parser.parse(data)

        let collection = RequestCollection(
            name: parsed.name,
            project: project,
            sortOrder: project.collections.count
        )
        modelContext.insert(collection)

        for (index, req) in parsed.requests.enumerated() {
            let request = APIRequest(
                name: req.name,
                method: req.method,
                urlTemplate: req.url,
                headers: req.headers,
                bodyType: req.bodyType,
                sortOrder: index
            )
            request.bodyContent = req.bodyContent
            request.collection = collection
            modelContext.insert(request)
        }
    }

    enum ImportError: Error, LocalizedError {
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Cannot access the selected file"
            }
        }
    }
}
