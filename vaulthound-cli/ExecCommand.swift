import ArgumentParser
import Foundation
import VaulthoundModels

struct ExecCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "exec",
        abstract: "Run a command with environment variables injected"
    )

    @Option(name: .long, help: "Project path (defaults to current directory)")
    var project: String?

    @Option(name: .long, help: "Environment name (defaults to 'local')")
    var env: String = "local"

    @Argument(parsing: .captureForPassthrough, help: "Command to execute")
    var command: [String] = []

    func run() async throws {
        guard !command.isEmpty else {
            throw ValidationError("No command specified. Usage: vaulthound exec -- <command>")
        }

        let projectPath = project ?? detectProjectPath()
        guard let projectPath else {
            throw ValidationError("Could not detect project. Use --project to specify the path.")
        }

        // Connect to daemon and resolve environment
        let client = SocketClient()
        let response = try client.sendRequest(SocketRequest(
            command: "resolve",
            projectPath: projectPath,
            environmentName: env
        ))

        guard response.success, let variables = response.variables else {
            let error = response.error ?? "Unknown error"
            throw ValidationError("Failed to resolve environment: \(error)")
        }

        // Spawn the command with injected environment variables
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = command

        // Merge with current environment
        var processEnv = ProcessInfo.processInfo.environment
        for (key, value) in variables {
            processEnv[key] = value
        }
        process.environment = processEnv

        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        process.standardInput = FileHandle.standardInput

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ExitCode(process.terminationStatus)
        }
    }

    /// Walk up from cwd to find a project root.
    private func detectProjectPath() -> String? {
        var current = URL(filePath: FileManager.default.currentDirectoryPath)

        let markers = [".vaulthound", ".git", "package.json", "Package.swift", "Cargo.toml", "pyproject.toml", "go.mod"]

        while current.path != "/" {
            for marker in markers {
                let markerPath = current.appending(path: marker).path
                if FileManager.default.fileExists(atPath: markerPath) {
                    return current.path
                }
            }
            current = current.deletingLastPathComponent()
        }

        return nil
    }
}
