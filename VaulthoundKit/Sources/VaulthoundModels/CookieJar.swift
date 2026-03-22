import SwiftData
import Foundation

public struct StoredCookie: Codable, Hashable, Sendable {
    public var name: String
    public var value: String
    public var path: String
    public var domain: String
    public var expiresAt: Date?
    public var isSecure: Bool
    public var isHTTPOnly: Bool

    public init(
        name: String,
        value: String,
        path: String = "/",
        domain: String,
        expiresAt: Date? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = false
    ) {
        self.name = name
        self.value = value
        self.path = path
        self.domain = domain
        self.expiresAt = expiresAt
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
    }

    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date.now
    }
}

@Model
public final class CookieJar {
    @Attribute(.unique) public var domain: String
    public var cookies: [StoredCookie]
    public var updatedAt: Date

    public init(domain: String, cookies: [StoredCookie] = []) {
        self.domain = domain
        self.cookies = cookies
        self.updatedAt = .now
    }
}
