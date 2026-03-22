import Foundation
import VaulthoundModels
import VaulthoundCore

struct PythonExporter {
    static func export(_ request: APIRequest, variables: [String: String] = [:]) -> String {
        let interpolator = VariableInterpolator()
        let url = interpolator.resolve(request.urlTemplate, using: variables)

        var lines: [String] = []
        lines.append("import requests")
        lines.append("")

        let enabledHeaders = request.headers.filter(\.isEnabled)
        if !enabledHeaders.isEmpty {
            lines.append("headers = {")
            for header in enabledHeaders {
                let value = interpolator.resolve(header.value, using: variables)
                lines.append("    \"\(header.key)\": \"\(value)\",")
            }
            lines.append("}")
            lines.append("")
        }

        let method = request.method.rawValue.lowercased()
        var callParts = ["response = requests.\(method)("]
        callParts.append("    \"\(url)\",")

        if !enabledHeaders.isEmpty {
            callParts.append("    headers=headers,")
        }

        if let body = request.bodyContent, request.bodyType != .none {
            switch request.bodyType {
            case .json:
                lines.insert("import json", at: 1)
                callParts.append("    json=\(body),")
            case .formData:
                callParts.append("    data=\"\(body)\",")
            default:
                callParts.append("    data=\"\(body)\",")
            }
        }

        callParts.append(")")
        lines.append(contentsOf: callParts)

        lines.append("")
        lines.append("print(f\"Status: {response.status_code}\")")
        lines.append("print(response.text)")

        return lines.joined(separator: "\n")
    }
}
