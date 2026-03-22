import SwiftData
import Foundation

@Model
public final class RequestCollection {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \APIRequest.collection)
    public var requests: [APIRequest]

    public var sortOrder: Int
    public var createdAt: Date

    public init(name: String, project: Project? = nil, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.project = project
        self.requests = []
        self.sortOrder = sortOrder
        self.createdAt = .now
    }
}
