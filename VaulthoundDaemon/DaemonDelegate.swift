import Foundation
import VaulthoundModels

final class DaemonDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.remoteObjectInterface = NSXPCInterface(with: VaulthoundDaemonClientProtocol.self)
        newConnection.exportedInterface = NSXPCInterface(with: VaulthoundDaemonProtocol.self)
        newConnection.exportedObject = DaemonService(connection: newConnection)
        newConnection.resume()
        return true
    }
}
