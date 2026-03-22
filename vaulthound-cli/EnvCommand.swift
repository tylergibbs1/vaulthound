import ArgumentParser
import Foundation
import VaulthoundModels

struct EnvCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "env",
        abstract: "Print environment variables for a project"
    )

    @Option(name: .long, help: "Project path (defaults to current directory)")
    var project: String?

    @Option(name: .long, help: "Environment name")
    var name: String = "local"

    @Flag(name: .long, help: "Output in .env file format")
    var dotenv: Bool = false

    @Flag(name: .long, help: "Output as shell export statements")
    var export: Bool = false

    func run() async throws {
        let projectPath = project ?? FileManager.default.currentDirectoryPath

        let client = SocketClient()
        let response = try client.sendRequest(SocketRequest(
            command: "env",
            projectPath: projectPath,
            environmentName: name
        ))

        guard response.success, let variables = response.variables else {
            let error = response.error ?? "Unknown error"
            print("Error: \(error)")
            throw ExitCode.failure
        }

        if variables.isEmpty {
            print("No variables found for environment '\(name)'.")
            return
        }

        for (key, value) in variables.sorted(by: { $0.key < $1.key }) {
            if export {
                print("export \(key)=\(shellEscape(value))")
            } else if dotenv {
                print("\(key)=\(value)")
            } else {
                print("\(key)=\(value)")
            }
        }
    }

    private func shellEscape(_ value: String) -> String {
        if value.contains(" ") || value.contains("\"") || value.contains("$") || value.contains("`") {
            return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
        }
        return value
    }
}
