import Foundation
import VaulthoundModels
import VaulthoundCore

final class DaemonService: NSObject, VaulthoundDaemonProtocol {
    private let connection: NSXPCConnection
    private let scanner = ProjectScanner()
    private let envParser = EnvParser()
    private var fileWatcher: FileWatcher?

    init(connection: NSXPCConnection) {
        self.connection = connection
        super.init()
    }

    func scanProjects(in directories: [String], reply: @escaping ([Data]) -> Void) {
        let expandedDirs = directories.map { dir -> String in
            NSString(string: dir).expandingTildeInPath
        }

        let discovered = scanner.scan(directories: expandedDirs)
        let encoded = discovered.compactMap { try? JSONEncoder().encode($0) }
        reply(encoded)
    }

    func watchDirectory(_ path: String, reply: @escaping (Bool) -> Void) {
        let expanded = NSString(string: path).expandingTildeInPath

        if fileWatcher == nil {
            fileWatcher = FileWatcher()
        }

        fileWatcher?.watch(directory: expanded) { [weak self] event in
            self?.notifyFileChange(event)
        }

        reply(true)
    }

    func unwatchDirectory(_ path: String, reply: @escaping (Bool) -> Void) {
        let expanded = NSString(string: path).expandingTildeInPath
        fileWatcher?.unwatch(directory: expanded)
        reply(true)
    }

    func checkGitignore(projectPath: String, envFileName: String, reply: @escaping (Bool) -> Void) {
        let checker = GitignoreChecker()
        let isProtected = checker.isIgnored(fileName: envFileName, in: projectPath)
        reply(isProtected)
    }

    func getDetectedProjects(reply: @escaping ([Data]) -> Void) {
        // Return cached discovered projects
        reply([])
    }

    func parseEnvFile(at path: String, reply: @escaping (Data?) -> Void) {
        let parsed = envParser.parse(filePath: path)
        let data = try? JSONEncoder().encode(parsed)
        reply(data)
    }

    func getMissingVariables(envPath: String, examplePath: String, reply: @escaping ([String]) -> Void) {
        let missing = envParser.findMissingVariables(envPath: envPath, examplePath: examplePath)
        reply(missing)
    }

    private func notifyFileChange(_ event: FileChangeEvent) {
        guard let client = connection.remoteObjectProxy as? VaulthoundDaemonClientProtocol,
              let data = try? JSONEncoder().encode(event) else { return }
        client.fileDidChange(data)
    }
}
