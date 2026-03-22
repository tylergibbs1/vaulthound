import SwiftData
import Foundation

public enum HTTPMethod: String, Codable, Sendable, CaseIterable {
    case GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
}

public enum BodyType: String, Codable, Sendable, CaseIterable {
    case none, json, formData, raw, xml
}

public struct RequestHeader: Codable, Hashable, Sendable {
    public var key: String
    public var value: String
    public var isEnabled: Bool

    public init(key: String, value: String, isEnabled: Bool = true) {
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }
}

@Model
public final class APIRequest {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var method: HTTPMethod
    public var urlTemplate: String
    public var headers: [RequestHeader]
    public var bodyType: BodyType
    public var bodyContent: String?
    public var collection: RequestCollection?
    public var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \APIResponse.request)
    public var responseHistory: [APIResponse]

    public var createdAt: Date
    public var updatedAt: Date

    public init(
        name: String,
        method: HTTPMethod = .GET,
        urlTemplate: String = "",
        headers: [RequestHeader] = [],
        bodyType: BodyType = .none,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.method = method
        self.urlTemplate = urlTemplate
        self.headers = headers
        self.bodyType = bodyType
        self.bodyContent = nil
        self.collection = nil
        self.sortOrder = sortOrder
        self.responseHistory = []
        self.createdAt = .now
        self.updatedAt = .now
    }
}
