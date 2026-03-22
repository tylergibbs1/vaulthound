import Testing
import Foundation
@testable import VaulthoundCore
import VaulthoundModels

@Suite("ProjectFileManager")
struct ProjectFileManagerTests {
    let pfm = ProjectFileManager()

    @Test("Scaffolds .vaulthound directory structure")
    func scaffold() throws {
        let tmp = NSTemporaryDirectory() + "vh-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        try pfm.scaffold(at: tmp, projectName: "test-project", detectedType: .node)

        #expect(pfm.hasVaulthoundConfig(at: tmp))

        let config = try pfm.readProjectConfig(at: tmp)
        #expect(config.name == "test-project")
        #expect(config.detectedType == "node")

        let envs = try pfm.listEnvironments(at: tmp)
        #expect(envs.contains("_base"))
        #expect(envs.contains("local"))
    }

    @Test("Writes and reads environment configs")
    func environmentRoundtrip() throws {
        let tmp = NSTemporaryDirectory() + "vh-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        try pfm.scaffold(at: tmp, projectName: "test", detectedType: .swift)

        let staging = ProjectFileManager.EnvironmentConfig(
            inherits: "_base",
            variables: [
                "BASE_URL": .plain("https://staging.example.com"),
                "API_KEY": .secret(.init(ref: "keychain:vh.test.staging.API_KEY", sourceHint: "Get from 1Password", provider: "generic")),
                "LOG_LEVEL": .plain("debug"),
            ]
        )

        try pfm.writeEnvironment(staging, at: tmp, name: "staging")

        let read = try pfm.readEnvironment(at: tmp, name: "staging")
        #expect(read.inherits == "_base")

        switch read.variables["BASE_URL"] {
        case .plain(let v): #expect(v == "https://staging.example.com")
        default: Issue.record("Expected plain value for BASE_URL")
        }

        switch read.variables["API_KEY"] {
        case .secret(let ref):
            #expect(ref.ref == "keychain:vh.test.staging.API_KEY")
            #expect(ref.sourceHint == "Get from 1Password")
        default: Issue.record("Expected secret ref for API_KEY")
        }
    }

    @Test("Writes and reads secrets lock")
    func secretsLock() throws {
        let tmp = NSTemporaryDirectory() + "vh-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        try pfm.scaffold(at: tmp, projectName: "test", detectedType: .unknown)

        let lock = ProjectFileManager.SecretsLock(secrets: [
            "local": ["API_KEY", "DB_PASSWORD"],
            "staging": ["API_KEY", "DB_PASSWORD", "STRIPE_KEY"],
        ])
        try pfm.writeSecretsLock(lock, at: tmp)

        let read = try pfm.readSecretsLock(at: tmp)
        #expect(read.secrets["local"]?.count == 2)
        #expect(read.secrets["staging"]?.contains("STRIPE_KEY") == true)
    }

    @Test("hasVaulthoundConfig returns false for bare directory")
    func noConfig() {
        let tmp = NSTemporaryDirectory() + "vh-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        #expect(!pfm.hasVaulthoundConfig(at: tmp))
    }

    @Test("listEnvironments returns empty for project without environments dir")
    func emptyEnvironments() throws {
        let tmp = NSTemporaryDirectory() + "vh-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: tmp) }

        #expect(try pfm.listEnvironments(at: tmp).isEmpty)
    }
}
