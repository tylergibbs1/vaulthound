import SwiftData
import Foundation

public struct RequestSnapshot: Codable, Sendable {
    public var method: String
    public var url: String
    public var headers: [String: String]
    public var body: String?

    public init(method: String, url: String, headers: [String: String], body: String? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct TimingBreakdown: Codable, Sendable {
    public var dnsMs: Double
    public var connectMs: Double
    public var tlsMs: Double
    public var ttfbMs: Double
    public var transferMs: Double
    public var totalMs: Double

    public init(dnsMs: Double = 0, connectMs: Double = 0, tlsMs: Double = 0, ttfbMs: Double = 0, transferMs: Double = 0, totalMs: Double = 0) {
        self.dnsMs = dnsMs
        self.connectMs = connectMs
        self.tlsMs = tlsMs
        self.ttfbMs = ttfbMs
        self.transferMs = transferMs
        self.totalMs = totalMs
    }
}

@Model
public final class APIResponse {
    @Attribute(.unique) public var id: UUID
    public var request: APIRequest?
    public var statusCode: Int
    public var responseHeaders: [String: String]
    public var body: Data
    public var bodyContentType: String?
    public var timing: TimingBreakdown
    public var requestSnapshot: RequestSnapshot
    public var receivedAt: Date

    public var bodyString: String? {
        String(data: body, encoding: .utf8)
    }

    public var bodySize: Int {
        body.count
    }

    public init(
        statusCode: Int,
        responseHeaders: [String: String] = [:],
        body: Data = Data(),
        bodyContentType: String? = nil,
        timing: TimingBreakdown = TimingBreakdown(),
        requestSnapshot: RequestSnapshot
    ) {
        self.id = UUID()
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.body = body
        self.bodyContentType = bodyContentType
        self.timing = timing
        self.requestSnapshot = requestSnapshot
        self.receivedAt = .now
    }
}
