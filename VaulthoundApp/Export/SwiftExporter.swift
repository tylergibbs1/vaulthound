import Foundation
import VaulthoundModels
import VaulthoundCore

struct SwiftExporter {
    static func export(_ request: APIRequest, variables: [String: String] = [:]) -> String {
        let interpolator = VariableInterpolator()
        let url = interpolator.resolve(request.urlTemplate, using: variables)

        var lines: [String] = []
        lines.append("import Foundation")
        lines.append("")
        lines.append("let url = URL(string: \"\(url)\")!")
        lines.append("var request = URLRequest(url: url)")
        lines.append("request.httpMethod = \"\(request.method.rawValue)\"")

        for header in request.headers where header.isEnabled {
            let value = interpolator.resolve(header.value, using: variables)
            lines.append("request.setValue(\"\(value)\", forHTTPHeaderField: \"\(header.key)\")")
        }

        if let body = request.bodyContent, request.bodyType != .none {
            let escaped = body.replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            lines.append("request.httpBody = \"\(escaped)\".data(using: .utf8)")
        }

        lines.append("")
        lines.append("let (data, response) = try await URLSession.shared.data(for: request)")
        lines.append("let httpResponse = response as! HTTPURLResponse")
        lines.append("print(\"Status: \\(httpResponse.statusCode)\")")
        lines.append("print(String(data: data, encoding: .utf8) ?? \"\")")

        return lines.joined(separator: "\n")
    }
}
