import SwiftData
import Foundation

@Model
public final class ProjectEnvironment {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var project: Project?
    public var isActive: Bool
    public var sourceFilePath: String?
    public var isWatching: Bool

    @Relationship(deleteRule: .cascade, inverse: \Variable.projectEnvironment)
    public var variables: [Variable]

    public var createdAt: Date
    public var updatedAt: Date

    public init(name: String, project: Project? = nil) {
        self.id = UUID()
        self.name = name
        self.project = project
        self.isActive = false
        self.sourceFilePath = nil
        self.isWatching = false
        self.variables = []
        self.createdAt = .now
        self.updatedAt = .now
    }
}
