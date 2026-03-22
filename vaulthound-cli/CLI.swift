import ArgumentParser

@main
struct VaulthoundCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "vaulthound",
        abstract: "The environment layer for macOS developers",
        version: "1.0.0",
        subcommands: [
            ExecCommand.self,
            ListCommand.self,
            EnvCommand.self,
            HookCommand.self,
        ]
    )
}
