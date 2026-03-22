import Foundation
import VaulthoundModels

/// XPC client proxy for communicating with the VaulthoundDaemon.
///
/// The daemon provides filesystem watching, project scanning, and CLI socket serving.
/// The app works fully without it — the daemon is an enhancement, not a requirement.
@MainActor
final class DaemonConnection: ObservableObject {
    static let shared = DaemonConnection()

    enum ConnectionState: Equatable {
        case idle
        case connected
        case unavailable  // XPC service not in bundle (dev builds)
        case disconnected // Was connected but lost connection
    }

    @Published var state: ConnectionState = .idle
    @Published var detectedProjects: [DiscoveredProject] = []

    var isConnected: Bool { state == .connected }

    private var connection: NSXPCConnection?

    private init() {}

    func connect() {
        // Verify the XPC service exists in our bundle before attempting connection.
        // NSXPCConnection.resume() traps (EXC_BREAKPOINT) if the service isn't found.
        let xpcServiceName = "com.vaulthound.app.daemon"
        guard let xpcDir = Bundle.main.url(forResource: "XPCServices", withExtension: nil),
              FileManager.default.fileExists(atPath: xpcDir.appending(path: "VaulthoundDaemon.xpc").path) else {
            NSLog("Vaulthound daemon XPC service not found in bundle — running in local mode")
            state = .unavailable
            return
        }

        let conn = NSXPCConnection(serviceName: xpcServiceName)
        conn.remoteObjectInterface = NSXPCInterface(with: VaulthoundDaemonProtocol.self)
        conn.exportedInterface = NSXPCInterface(with: VaulthoundDaemonClientProtocol.self)
        conn.exportedObject = DaemonCallbackHandler(connection: self)

        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.state = .disconnected
                self?.connection = nil
            }
        }

        conn.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.state = .disconnected
            }
        }

        conn.resume()
        connection = conn
        state = .connected
    }

    func disconnect() {
        connection?.invalidate()
        connection = nil
        state = .disconnected
    }

    func scanProjects(in directories: [String]) async -> [DiscoveredProject] {
        guard let conn = connection else { return [] }

        let proxy = conn.remoteObjectProxyWithErrorHandler { error in
            NSLog("Vaulthound daemon error: \(error.localizedDescription)")
        }

        guard let daemon = proxy as? VaulthoundDaemonProtocol else { return [] }

        return await withCheckedContinuation { continuation in
            daemon.scanProjects(in: directories) { dataArray in
                let projects = dataArray.compactMap { data in
                    try? JSONDecoder().decode(DiscoveredProject.self, from: data)
                }
                continuation.resume(returning: projects)
            }
        }
    }

    func watchDirectory(_ path: String) async -> Bool {
        guard let conn = connection else { return false }

        let proxy = conn.remoteObjectProxyWithErrorHandler { _ in }
        guard let daemon = proxy as? VaulthoundDaemonProtocol else { return false }

        return await withCheckedContinuation { continuation in
            daemon.watchDirectory(path) { success in
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - Callbacks

    func handleFileChange(_ event: FileChangeEvent) {
        NotificationCenter.default.post(
            name: .vaulthoundFileChanged,
            object: nil,
            userInfo: ["event": event]
        )
    }

    func handleProjectDiscovered(_ project: DiscoveredProject) {
        detectedProjects.append(project)
    }
}

extension Notification.Name {
    static let vaulthoundFileChanged = Notification.Name("vaulthoundFileChanged")
}

// MARK: - Callback Handler

private class DaemonCallbackHandler: NSObject, VaulthoundDaemonClientProtocol {
    weak var connection: DaemonConnection?

    init(connection: DaemonConnection) {
        self.connection = connection
    }

    func fileDidChange(_ eventData: Data) {
        guard let event = try? JSONDecoder().decode(FileChangeEvent.self, from: eventData) else { return }
        let conn = connection
        Task { @MainActor in
            conn?.handleFileChange(event)
        }
    }

    func projectDiscovered(_ projectData: Data) {
        guard let project = try? JSONDecoder().decode(DiscoveredProject.self, from: projectData) else { return }
        let conn = connection
        Task { @MainActor in
            conn?.handleProjectDiscovered(project)
        }
    }
}
