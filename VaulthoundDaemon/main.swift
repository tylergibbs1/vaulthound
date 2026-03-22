import Foundation

let delegate = DaemonDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

// Also start the Unix socket server for CLI communication
let socketServer = SocketServer()
socketServer.start()

// Keep the daemon running
RunLoop.current.run()
