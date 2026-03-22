import Foundation

/// Discovered project info passed between daemon and app via XPC.
public struct DiscoveredProject: Codable, Sendable {
    public var name: String
    public var path: String
    public var detectedType: String
    public var envFiles: [String]
    public var hasGitignoreProtection: Bool

    public init(name: String, path: String, detectedType: String, envFiles: [String], hasGitignoreProtection: Bool) {
        self.name = name
        self.path = path
        self.detectedType = detectedType
        self.envFiles = envFiles
        self.hasGitignoreProtection = hasGitignoreProtection
    }
}

/// File change event from the daemon's FSEvents watcher.
public struct FileChangeEvent: Codable, Sendable {
    public var path: String
    public var projectPath: String
    public var changeType: ChangeType

    public enum ChangeType: String, Codable, Sendable {
        case created, modified, deleted
    }

    public init(path: String, projectPath: String, changeType: ChangeType) {
        self.path = path
        self.projectPath = projectPath
        self.changeType = changeType
    }
}

/// XPC protocol for communication between the app and the background daemon.
@objc public protocol VaulthoundDaemonProtocol {
    func scanProjects(in directories: [String], reply: @escaping ([Data]) -> Void)
    func watchDirectory(_ path: String, reply: @escaping (Bool) -> Void)
    func unwatchDirectory(_ path: String, reply: @escaping (Bool) -> Void)
    func checkGitignore(projectPath: String, envFileName: String, reply: @escaping (Bool) -> Void)
    func getDetectedProjects(reply: @escaping ([Data]) -> Void)
    func parseEnvFile(at path: String, reply: @escaping (Data?) -> Void)
    func getMissingVariables(envPath: String, examplePath: String, reply: @escaping ([String]) -> Void)
}

/// Protocol for callbacks from daemon to app (file changes, new project detection).
@objc public protocol VaulthoundDaemonClientProtocol {
    func fileDidChange(_ eventData: Data)
    func projectDiscovered(_ projectData: Data)
}

// MARK: - Socket Protocol (CLI ↔ Daemon)

/// JSON-based messages for the Unix socket protocol between CLI and daemon.
public struct SocketRequest: Codable, Sendable {
    public var command: String
    public var projectPath: String?
    public var environmentName: String?
    public var arguments: [String: String]?

    public init(command: String, projectPath: String? = nil, environmentName: String? = nil, arguments: [String: String]? = nil) {
        self.command = command
        self.projectPath = projectPath
        self.environmentName = environmentName
        self.arguments = arguments
    }
}

public struct SocketResponse: Codable, Sendable {
    public var success: Bool
    public var data: [String: String]?
    public var error: String?
    public var variables: [String: String]?

    public init(success: Bool, data: [String: String]? = nil, error: String? = nil, variables: [String: String]? = nil) {
        self.success = success
        self.data = data
        self.error = error
        self.variables = variables
    }
}
