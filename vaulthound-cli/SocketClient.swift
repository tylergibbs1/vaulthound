import Foundation
import VaulthoundModels

/// Connects to the daemon's Unix domain socket and sends requests.
struct SocketClient {
    private let socketPath: String

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        socketPath = appSupport.appending(path: "Vaulthound/daemon.sock").path
    }

    func sendRequest(_ request: SocketRequest) throws -> SocketResponse {
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw SocketError.connectionFailed("Failed to create socket")
        }
        defer { close(sock) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = socketPath.utf8CString
        withUnsafeMutableBytes(of: &addr.sun_path) { rawBuf in
            let count = min(pathBytes.count, rawBuf.count)
            for i in 0..<count {
                rawBuf[i] = UInt8(bitPattern: pathBytes[i])
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connectResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(sock, sockaddrPtr, addrLen)
            }
        }

        guard connectResult == 0 else {
            throw SocketError.connectionFailed(
                "Cannot connect to Vaulthound daemon. Is the app running?\n" +
                "Socket path: \(socketPath)"
            )
        }

        // Send request
        let requestData = try JSONEncoder().encode(request)
        try requestData.withUnsafeBytes { ptr in
            let written = write(sock, ptr.baseAddress!, requestData.count)
            guard written == requestData.count else {
                throw SocketError.writeFailed
            }
        }

        // Read response
        var buffer = [UInt8](repeating: 0, count: 1_048_576)  // 1MB max response
        let bytesRead = read(sock, &buffer, buffer.count)
        guard bytesRead > 0 else {
            throw SocketError.readFailed
        }

        let responseData = Data(buffer[0..<bytesRead])
        return try JSONDecoder().decode(SocketResponse.self, from: responseData)
    }

    enum SocketError: Error, LocalizedError {
        case connectionFailed(String)
        case writeFailed
        case readFailed

        var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): return msg
            case .writeFailed: return "Failed to send request to daemon"
            case .readFailed: return "Failed to read response from daemon"
            }
        }
    }
}
