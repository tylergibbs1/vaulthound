import Foundation
import VaulthoundModels

/// Parses a cURL command string into an APIRequest's constituent parts.
public struct CurlParser: Sendable {

    public struct ParsedRequest: Sendable {
        public var method: HTTPMethod
        public var url: String
        public var headers: [RequestHeader]
        public var bodyContent: String?
        public var bodyType: BodyType

        public init(method: HTTPMethod = .GET, url: String = "", headers: [RequestHeader] = [], bodyContent: String? = nil, bodyType: BodyType = .none) {
            self.method = method
            self.url = url
            self.headers = headers
            self.bodyContent = bodyContent
            self.bodyType = bodyType
        }
    }

    public init() {}

    public func parse(_ curl: String) -> ParsedRequest? {
        let tokens = tokenize(curl)
        guard !tokens.isEmpty else { return nil }

        // First token should be "curl"
        var idx = 0
        if tokens[idx].lowercased() == "curl" {
            idx += 1
        }

        var result = ParsedRequest()
        var explicitMethod: HTTPMethod?

        while idx < tokens.count {
            let token = tokens[idx]

            switch token {
            case "-X", "--request":
                idx += 1
                if idx < tokens.count, let method = HTTPMethod(rawValue: tokens[idx].uppercased()) {
                    explicitMethod = method
                }

            case "-H", "--header":
                idx += 1
                if idx < tokens.count {
                    if let header = parseHeader(tokens[idx]) {
                        result.headers.append(header)
                    }
                }

            case "-d", "--data", "--data-raw", "--data-binary":
                idx += 1
                if idx < tokens.count {
                    result.bodyContent = tokens[idx]
                    result.bodyType = inferBodyType(from: result.headers, body: tokens[idx])
                }

            case "--data-urlencode":
                idx += 1
                if idx < tokens.count {
                    if result.bodyContent != nil {
                        result.bodyContent! += "&\(tokens[idx])"
                    } else {
                        result.bodyContent = tokens[idx]
                    }
                    result.bodyType = .formData
                }

            case "-b", "--cookie":
                idx += 1
                if idx < tokens.count {
                    result.headers.append(RequestHeader(key: "Cookie", value: tokens[idx]))
                }

            case "-A", "--user-agent":
                idx += 1
                if idx < tokens.count {
                    result.headers.append(RequestHeader(key: "User-Agent", value: tokens[idx]))
                }

            case "-u", "--user":
                idx += 1
                if idx < tokens.count {
                    let encoded = Data(tokens[idx].utf8).base64EncodedString()
                    result.headers.append(RequestHeader(key: "Authorization", value: "Basic \(encoded)"))
                }

            default:
                // Bare argument — likely the URL
                if !token.hasPrefix("-") && result.url.isEmpty {
                    result.url = token.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                }
            }

            idx += 1
        }

        if let method = explicitMethod {
            result.method = method
        } else if result.bodyContent != nil {
            result.method = .POST
        }

        return result.url.isEmpty ? nil : result
    }

    // MARK: - Tokenization

    /// Shell-aware tokenizer that respects single and double quotes.
    private func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escaped = false

        // Normalize line continuations
        let normalized = input
            .replacingOccurrences(of: "\\\n", with: " ")
            .replacingOccurrences(of: "\\\r\n", with: " ")

        for char in normalized {
            if escaped {
                current.append(char)
                escaped = false
                continue
            }

            if char == "\\" && !inSingleQuote {
                escaped = true
                continue
            }

            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                continue
            }

            if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                continue
            }

            if char.isWhitespace && !inSingleQuote && !inDoubleQuote {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }

            current.append(char)
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }

    private func parseHeader(_ raw: String) -> RequestHeader? {
        guard let colonIndex = raw.firstIndex(of: ":") else { return nil }
        let key = String(raw[raw.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
        let value = String(raw[raw.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
        return RequestHeader(key: key, value: value)
    }

    private func inferBodyType(from headers: [RequestHeader], body: String) -> BodyType {
        let contentType = headers
            .first { $0.key.lowercased() == "content-type" }?.value.lowercased() ?? ""

        if contentType.contains("json") { return .json }
        if contentType.contains("xml") { return .xml }
        if contentType.contains("form-urlencoded") { return .formData }

        // Heuristic: if body starts with { or [, it's JSON
        let trimmed = body.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") { return .json }

        return .raw
    }
}
