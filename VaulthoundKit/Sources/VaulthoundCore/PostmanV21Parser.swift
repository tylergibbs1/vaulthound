import Foundation
import VaulthoundModels

/// Parses Postman Collection v2.1 JSON format into Vaulthound models.
public struct PostmanV21Parser: Sendable {

    public struct ParsedCollection: Sendable {
        public var name: String
        public var requests: [ParsedRequest]

        public struct ParsedRequest: Sendable {
            public var name: String
            public var method: HTTPMethod
            public var url: String
            public var headers: [RequestHeader]
            public var bodyType: BodyType
            public var bodyContent: String?
            public var folderPath: [String]
        }
    }

    public init() {}

    public func parse(_ data: Data) throws -> ParsedCollection {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let json else {
            throw ParserError.invalidFormat("Root is not a JSON object")
        }

        let info = json["info"] as? [String: Any] ?? [:]
        let collectionName = info["name"] as? String ?? "Imported Collection"

        let items = json["item"] as? [[String: Any]] ?? []
        var requests: [ParsedCollection.ParsedRequest] = []
        parseItems(items, folderPath: [], into: &requests)

        return ParsedCollection(name: collectionName, requests: requests)
    }

    private func parseItems(
        _ items: [[String: Any]],
        folderPath: [String],
        into requests: inout [ParsedCollection.ParsedRequest]
    ) {
        for item in items {
            let name = item["name"] as? String ?? "Untitled"

            // Folder (has nested items)
            if let subItems = item["item"] as? [[String: Any]] {
                parseItems(subItems, folderPath: folderPath + [name], into: &requests)
                continue
            }

            // Request
            guard let requestObj = item["request"] else { continue }

            if let request = parseRequest(requestObj, name: name, folderPath: folderPath) {
                requests.append(request)
            }
        }
    }

    private func parseRequest(
        _ obj: Any,
        name: String,
        folderPath: [String]
    ) -> ParsedCollection.ParsedRequest? {
        // Request can be a string (just URL) or an object
        if let urlString = obj as? String {
            return ParsedCollection.ParsedRequest(
                name: name, method: .GET, url: urlString,
                headers: [], bodyType: .none, bodyContent: nil,
                folderPath: folderPath
            )
        }

        guard let dict = obj as? [String: Any] else { return nil }

        let method = HTTPMethod(rawValue: (dict["method"] as? String ?? "GET").uppercased()) ?? .GET
        let url = extractURL(from: dict["url"])
        let headers = parseHeaders(dict["header"] as? [[String: Any]] ?? [])
        let (bodyType, bodyContent) = parseBody(dict["body"] as? [String: Any])

        return ParsedCollection.ParsedRequest(
            name: name, method: method, url: url,
            headers: headers, bodyType: bodyType, bodyContent: bodyContent,
            folderPath: folderPath
        )
    }

    private func extractURL(from urlObj: Any?) -> String {
        if let urlString = urlObj as? String { return urlString }

        guard let urlDict = urlObj as? [String: Any] else { return "" }

        if let raw = urlDict["raw"] as? String { return raw }

        // Build from components
        let host = (urlDict["host"] as? [String])?.joined(separator: ".") ?? ""
        let path = (urlDict["path"] as? [String])?.joined(separator: "/") ?? ""
        let protocol_ = urlDict["protocol"] as? String ?? "https"

        return "\(protocol_)://\(host)/\(path)"
    }

    private func parseHeaders(_ headers: [[String: Any]]) -> [RequestHeader] {
        headers.compactMap { dict in
            guard let key = dict["key"] as? String,
                  let value = dict["value"] as? String else { return nil }
            let disabled = dict["disabled"] as? Bool ?? false
            return RequestHeader(key: key, value: value, isEnabled: !disabled)
        }
    }

    private func parseBody(_ body: [String: Any]?) -> (BodyType, String?) {
        guard let body else { return (.none, nil) }

        let mode = body["mode"] as? String ?? ""

        switch mode {
        case "raw":
            let content = body["raw"] as? String
            let options = body["options"] as? [String: Any]
            let rawOptions = options?["raw"] as? [String: Any]
            let language = rawOptions?["language"] as? String ?? ""

            let type: BodyType = language == "json" ? .json : (language == "xml" ? .xml : .raw)
            return (type, content)

        case "urlencoded":
            let pairs = body["urlencoded"] as? [[String: Any]] ?? []
            let encoded = pairs.compactMap { pair -> String? in
                guard let key = pair["key"] as? String,
                      let value = pair["value"] as? String else { return nil }
                return "\(key)=\(value)"
            }.joined(separator: "&")
            return (.formData, encoded)

        case "formdata":
            let pairs = body["formdata"] as? [[String: Any]] ?? []
            let encoded = pairs.compactMap { pair -> String? in
                guard let key = pair["key"] as? String,
                      let value = pair["value"] as? String else { return nil }
                return "\(key)=\(value)"
            }.joined(separator: "&")
            return (.formData, encoded)

        default:
            return (.none, nil)
        }
    }

    public enum ParserError: Error, LocalizedError {
        case invalidFormat(String)

        public var errorDescription: String? {
            switch self {
            case .invalidFormat(let msg): return "Invalid Postman collection: \(msg)"
            }
        }
    }
}
