import Foundation
import VaulthoundModels

/// Reads and writes the `.vaulthound/` directory structure.
///
/// This directory is the portable, git-committable representation of a project's
/// environment configuration. Secrets are referenced by `$ref` pointers to Keychain,
/// not stored directly.
public struct ProjectFileManager {

    // MARK: - Project Config

    public struct ProjectConfig: Codable, Sendable {
        public var name: String
        public var detectedType: String
        public var scanDirectories: [String]?
        public var createdAt: String

        public init(name: String, detectedType: String, scanDirectories: [String]? = nil) {
            self.name = name
            self.detectedType = detectedType
            self.scanDirectories = scanDirectories
            self.createdAt = ISO8601DateFormatter().string(from: .now)
        }
    }

    // MARK: - Environment Config

    public struct EnvironmentConfig: Codable, Sendable {
        public var inherits: String?
        public var variables: [String: VariableValue]

        public init(inherits: String? = nil, variables: [String: VariableValue] = [:]) {
            self.inherits = inherits
            self.variables = variables
        }
    }

    public enum VariableValue: Codable, Sendable {
        case plain(String)
        case secret(SecretRef)

        public struct SecretRef: Codable, Sendable {
            public var ref: String
            public var sourceHint: String?
            public var provider: String?

            enum CodingKeys: String, CodingKey {
                case ref = "$ref"
                case sourceHint = "source_hint"
                case provider
            }

            public init(ref: String, sourceHint: String? = nil, provider: String? = nil) {
                self.ref = ref
                self.sourceHint = sourceHint
                self.provider = provider
            }
        }

        public init(from decoder: Decoder) throws {
            if let str = try? decoder.singleValueContainer().decode(String.self) {
                self = .plain(str)
            } else {
                self = .secret(try SecretRef(from: decoder))
            }
        }

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .plain(let str):
                var container = encoder.singleValueContainer()
                try container.encode(str)
            case .secret(let ref):
                try ref.encode(to: encoder)
            }
        }
    }

    // MARK: - API Request Config

    public struct APIRequestConfig: Codable, Sendable {
        public var name: String
        public var method: String
        public var url: String
        public var headers: [String: String]?
        public var bodyType: String?
        public var body: String?

        public init(name: String, method: String, url: String, headers: [String: String]? = nil, bodyType: String? = nil, body: String? = nil) {
            self.name = name
            self.method = method
            self.url = url
            self.headers = headers
            self.bodyType = bodyType
            self.body = body
        }
    }

    // MARK: - Secrets Lock

    public struct SecretsLock: Codable, Sendable {
        public var secrets: [String: [String]]  // envName -> [variableKeys]

        public init(secrets: [String: [String]] = [:]) {
            self.secrets = secrets
        }
    }

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    // MARK: - Read

    public func readProjectConfig(at projectPath: String) throws -> ProjectConfig {
        let url = URL(filePath: projectPath).appending(path: ".vaulthound/project.json")
        let data = try Data(contentsOf: url)
        return try decoder.decode(ProjectConfig.self, from: data)
    }

    public func readEnvironment(at projectPath: String, name: String) throws -> EnvironmentConfig {
        let url = URL(filePath: projectPath)
            .appending(path: ".vaulthound/environments/\(name).json")
        let data = try Data(contentsOf: url)
        return try decoder.decode(EnvironmentConfig.self, from: data)
    }

    public func listEnvironments(at projectPath: String) throws -> [String] {
        let envsDir = URL(filePath: projectPath).appending(path: ".vaulthound/environments")
        guard fileManager.fileExists(atPath: envsDir.path) else { return [] }

        return try fileManager.contentsOfDirectory(atPath: envsDir.path)
            .filter { $0.hasSuffix(".json") }
            .map { String($0.dropLast(5)) }  // strip .json
            .sorted()
    }

    public func readSecretsLock(at projectPath: String) throws -> SecretsLock {
        let url = URL(filePath: projectPath).appending(path: ".vaulthound/secrets.lock")
        let data = try Data(contentsOf: url)
        return try decoder.decode(SecretsLock.self, from: data)
    }

    // MARK: - Write

    public func writeProjectConfig(_ config: ProjectConfig, at projectPath: String) throws {
        let dirURL = URL(filePath: projectPath).appending(path: ".vaulthound")
        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let data = try encoder.encode(config)
        try data.write(to: dirURL.appending(path: "project.json"))
    }

    public func writeEnvironment(_ config: EnvironmentConfig, at projectPath: String, name: String) throws {
        let envsDir = URL(filePath: projectPath).appending(path: ".vaulthound/environments")
        try fileManager.createDirectory(at: envsDir, withIntermediateDirectories: true)

        let data = try encoder.encode(config)
        try data.write(to: envsDir.appending(path: "\(name).json"))
    }

    public func writeSecretsLock(_ lock: SecretsLock, at projectPath: String) throws {
        let dirURL = URL(filePath: projectPath).appending(path: ".vaulthound")
        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let data = try encoder.encode(lock)
        try data.write(to: dirURL.appending(path: "secrets.lock"))
    }

    // MARK: - Scaffold

    /// Creates the initial `.vaulthound/` directory structure for a project.
    public func scaffold(at projectPath: String, projectName: String, detectedType: ProjectType) throws {
        let config = ProjectConfig(name: projectName, detectedType: detectedType.rawValue)
        try writeProjectConfig(config, at: projectPath)

        // Create default environments
        let baseEnv = EnvironmentConfig(variables: [:])
        try writeEnvironment(baseEnv, at: projectPath, name: "_base")
        try writeEnvironment(EnvironmentConfig(inherits: "_base"), at: projectPath, name: "local")

        // Create empty API directory
        let apiDir = URL(filePath: projectPath).appending(path: ".vaulthound/api")
        try fileManager.createDirectory(at: apiDir, withIntermediateDirectories: true)

        // Create secrets.lock
        try writeSecretsLock(SecretsLock(), at: projectPath)
    }

    /// Returns true if a `.vaulthound/` directory exists at the given path.
    public func hasVaulthoundConfig(at projectPath: String) -> Bool {
        let configPath = URL(filePath: projectPath).appending(path: ".vaulthound/project.json").path
        return fileManager.fileExists(atPath: configPath)
    }
}
