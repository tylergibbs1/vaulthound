import Foundation
import VaulthoundModels
import VaulthoundCore

/// Unix domain socket server for CLI ↔ Daemon communication.
final class SocketServer {
    private let socketPath: String
    private var serverSocket: Int32 = -1
    private let scanner = ProjectScanner()

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appending(path: "Vaulthound")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        socketPath = dir.appending(path: "daemon.sock").path
    }

    func start() {
        // Remove existing socket file
        unlink(socketPath)

        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        // Copy socket path into sun_path
        let pathBytes = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { rawBuf in
            let count = min(pathBytes.count, rawBuf.count)
            for i in 0..<count {
                rawBuf[i] = UInt8(bitPattern: pathBytes[i])
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, addrLen)
            }
        }

        guard bindResult == 0 else { return }

        listen(serverSocket, 5)

        // Accept connections on a background thread
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.acceptLoop()
        }
    }

    private func acceptLoop() {
        while serverSocket >= 0 {
            let clientSocket = accept(serverSocket, nil, nil)
            guard clientSocket >= 0 else { continue }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(clientSocket)
            }
        }
    }

    private func handleClient(_ socket: Int32) {
        defer { close(socket) }

        // Read request
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(socket, &buffer, buffer.count)
        guard bytesRead > 0 else { return }

        let data = Data(buffer[0..<bytesRead])

        guard let request = try? JSONDecoder().decode(SocketRequest.self, from: data) else {
            sendResponse(socket, SocketResponse(success: false, error: "Invalid request"))
            return
        }

        let response = processRequest(request)
        sendResponse(socket, response)
    }

    private func processRequest(_ request: SocketRequest) -> SocketResponse {
        switch request.command {
        case "resolve":
            return resolveEnvironment(request)
        case "list":
            return listProjects()
        case "env":
            return getEnvironmentVariables(request)
        default:
            return SocketResponse(success: false, error: "Unknown command: \(request.command)")
        }
    }

    private func resolveEnvironment(_ request: SocketRequest) -> SocketResponse {
        guard let projectPath = request.projectPath else {
            return SocketResponse(success: false, error: "No project path specified")
        }

        let envName = request.environmentName ?? "local"
        let envFilePath = "\(projectPath)/.env"

        // Parse the env file
        guard FileManager.default.fileExists(atPath: envFilePath) else {
            // Try .vaulthound/ config
            let vhEnvPath = "\(projectPath)/.vaulthound/environments/\(envName).json"
            guard FileManager.default.fileExists(atPath: vhEnvPath) else {
                return SocketResponse(success: false, error: "No environment file found")
            }

            // Parse .vaulthound config
            let pfm = ProjectFileManager()
            guard let envConfig = try? pfm.readEnvironment(at: projectPath, name: envName) else {
                return SocketResponse(success: false, error: "Failed to parse environment config")
            }

            var variables: [String: String] = [:]
            for (key, value) in envConfig.variables {
                switch value {
                case .plain(let v):
                    variables[key] = v
                case .secret(let ref):
                    // Try to read from Keychain
                    if let keychainKey = SecureReference(ref: ref.ref).keychainAccountKey {
                        let keychain = VaulthoundSecurity.KeychainAccess()
                        variables[key] = (try? keychain.read(account: keychainKey)) ?? ""
                    }
                }
            }

            return SocketResponse(success: true, variables: variables)
        }

        // Parse .env file
        let codec = EnvFileCodec()
        guard let content = try? String(contentsOfFile: envFilePath, encoding: .utf8) else {
            return SocketResponse(success: false, error: "Failed to read .env file")
        }

        let pairs = codec.parseVariables(content)
        let variables = Dictionary(uniqueKeysWithValues: pairs)

        return SocketResponse(success: true, variables: variables)
    }

    private func listProjects() -> SocketResponse {
        let defaultDirs = ["~/Developer", "~/Projects", "~/Code"].map {
            NSString(string: $0).expandingTildeInPath
        }

        let projects = scanner.scan(directories: defaultDirs)
        let data = projects.reduce(into: [String: String]()) { result, project in
            result[project.name] = project.path
        }

        return SocketResponse(success: true, data: data)
    }

    private func getEnvironmentVariables(_ request: SocketRequest) -> SocketResponse {
        return resolveEnvironment(request)
    }

    private func sendResponse(_ socket: Int32, _ response: SocketResponse) {
        guard let data = try? JSONEncoder().encode(response) else { return }
        data.withUnsafeBytes { ptr in
            _ = write(socket, ptr.baseAddress!, data.count)
        }
    }

    deinit {
        if serverSocket >= 0 {
            close(serverSocket)
        }
        unlink(socketPath)
    }
}

import VaulthoundSecurity
