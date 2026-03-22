import Foundation
import SwiftData
import VaulthoundModels
import VaulthoundCore

@MainActor
struct CurlImporter {
    let modelContext: ModelContext

    func importCurl(_ curlString: String, into collection: RequestCollection) throws {
        let parser = CurlParser()
        guard let parsed = parser.parse(curlString) else {
            throw ImportError.invalidCurl
        }

        // Extract a name from the URL
        let name: String
        if let url = URL(string: parsed.url) {
            name = url.lastPathComponent.isEmpty ? url.host ?? "Request" : url.lastPathComponent
        } else {
            name = "Imported Request"
        }

        let request = APIRequest(
            name: name,
            method: parsed.method,
            urlTemplate: parsed.url,
            headers: parsed.headers,
            bodyType: parsed.bodyType,
            sortOrder: collection.requests.count
        )
        request.bodyContent = parsed.bodyContent
        request.collection = collection
        modelContext.insert(request)
    }

    enum ImportError: Error, LocalizedError {
        case invalidCurl

        var errorDescription: String? {
            switch self {
            case .invalidCurl: return "Could not parse the cURL command"
            }
        }
    }
}
