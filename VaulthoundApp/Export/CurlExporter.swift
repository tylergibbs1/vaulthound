import Foundation
import VaulthoundModels
import VaulthoundCore

struct CurlExporter {
    static func export(_ request: APIRequest, variables: [String: String] = [:]) -> String {
        let interpolator = VariableInterpolator()
        let url = interpolator.resolve(request.urlTemplate, using: variables)

        var parts = ["curl"]

        if request.method != .GET {
            parts.append("-X \(request.method.rawValue)")
        }

        for header in request.headers where header.isEnabled {
            let value = interpolator.resolve(header.value, using: variables)
            parts.append("-H '\(header.key): \(value)'")
        }

        if let body = request.bodyContent, request.bodyType != .none {
            let resolvedBody = interpolator.resolve(body, using: variables)
            parts.append("-d '\(resolvedBody.replacingOccurrences(of: "'", with: "'\\''"))'")
        }

        parts.append("'\(url)'")

        return parts.joined(separator: " \\\n  ")
    }
}
