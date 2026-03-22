import SwiftData
import Foundation

public enum ProjectType: String, Codable, Sendable, CaseIterable {
    case swift
    case node
    case rust
    case python
    case go
    case ruby
    case java
    case unknown
}

@Model
public final class Project {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var path: String
    public var detectedType: ProjectType
    public var isActive: Bool
    public var lastScannedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ProjectEnvironment.project)
    public var environments: [ProjectEnvironment]

    @Relationship(deleteRule: .cascade, inverse: \RequestCollection.project)
    public var collections: [RequestCollection]

    public var createdAt: Date
    public var updatedAt: Date

    public init(name: String, path: String, detectedType: ProjectType = .unknown) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.detectedType = detectedType
        self.isActive = false
        self.environments = []
        self.collections = []
        self.createdAt = .now
        self.updatedAt = .now
    }
}
