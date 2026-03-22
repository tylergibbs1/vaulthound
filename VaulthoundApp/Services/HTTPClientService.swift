import Foundation
import VaulthoundModels
import VaulthoundCore

/// Executes HTTP requests with variable interpolation, cookie handling, and timing.
@MainActor
final class HTTPClientService {
    static let shared = HTTPClientService()

    let cookieStore = CookieStore()

    private init() {}

    struct ExecutionResult {
        var statusCode: Int
        var headers: [String: String]
        var body: Data
        var contentType: String?
        var timing: TimingBreakdown
    }

    func execute(
        request: APIRequest,
        variables: [String: String]
    ) async throws -> ExecutionResult {
        let interpolator = VariableInterpolator()

        // Interpolate URL
        let resolvedURL = interpolator.resolve(request.urlTemplate, using: variables)
        guard let url = URL(string: resolvedURL) else {
            throw HTTPError.invalidURL(resolvedURL)
        }

        // Build URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        // Interpolate and set headers
        for header in request.headers where header.isEnabled {
            let resolvedValue = interpolator.resolve(header.value, using: variables)
            urlRequest.setValue(resolvedValue, forHTTPHeaderField: header.key)
        }

        // Set cookies from cookie store
        if let cookieHeader = cookieStore.cookieHeader(for: url) {
            urlRequest.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        // Set body
        if let bodyContent = request.bodyContent, request.bodyType != .none {
            let resolvedBody = interpolator.resolve(bodyContent, using: variables)
            urlRequest.httpBody = resolvedBody.data(using: .utf8)

            // Set content type if not already set
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                switch request.bodyType {
                case .json: urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                case .xml: urlRequest.setValue("application/xml", forHTTPHeaderField: "Content-Type")
                case .formData: urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                case .raw, .none: break
                }
            }
        }

        // Execute with timing
        let startTime = CFAbsoluteTimeGetCurrent()

        let session = URLSession(configuration: .ephemeral)
        let (data, response) = try await session.data(for: urlRequest)

        let totalMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.notHTTPResponse
        }

        // Process Set-Cookie headers
        let setCookieHeaders = httpResponse.allHeaderFields
            .filter { ($0.key as? String)?.lowercased() == "set-cookie" }
            .compactMap { $0.value as? String }
        cookieStore.processSetCookieHeaders(setCookieHeaders, for: url)

        // Convert headers
        let responseHeaders: [String: String] = Dictionary(
            uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value -> (String, String)? in
                guard let k = key as? String, let v = value as? String else { return nil }
                return (k, v)
            }
        )

        let timing = TimingBreakdown(totalMs: totalMs)

        return ExecutionResult(
            statusCode: httpResponse.statusCode,
            headers: responseHeaders,
            body: data,
            contentType: httpResponse.mimeType,
            timing: timing
        )
    }

    enum HTTPError: Error, LocalizedError {
        case invalidURL(String)
        case notHTTPResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL(let url): return "Invalid URL: \(url)"
            case .notHTTPResponse: return "Response was not HTTP"
            }
        }
    }
}
