import ArgumentParser
import Foundation
import VaulthoundModels

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List detected projects and their environments"
    )

    func run() async throws {
        let client = SocketClient()
        let response = try client.sendRequest(SocketRequest(command: "list"))

        guard response.success else {
            let error = response.error ?? "Unknown error"
            print("Error: \(error)")
            throw ExitCode.failure
        }

        if let data = response.data {
            if data.isEmpty {
                print("No projects detected.")
                print("Tip: Add project directories in Vaulthound Preferences, or use 'vaulthound exec --project <path>'")
                return
            }

            print("Detected Projects:")
            print(String(repeating: "─", count: 50))

            for (name, path) in data.sorted(by: { $0.key < $1.key }) {
                print("  \(name)")
                print("    \(path)")
            }
        } else {
            print("No projects found.")
        }
    }
}
