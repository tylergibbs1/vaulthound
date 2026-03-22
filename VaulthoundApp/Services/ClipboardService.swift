import AppKit

/// Centralized clipboard operations with auto-clear for secrets.
@MainActor
enum ClipboardService {
    /// Copy a value to the clipboard. If `isSecret`, auto-clears after 30 seconds.
    static func copy(_ value: String, isSecret: Bool = false) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)

        guard isSecret else { return }

        let changeCount = pasteboard.changeCount
        Task {
            try? await Task.sleep(for: .seconds(30))
            if pasteboard.changeCount == changeCount {
                pasteboard.clearContents()
            }
        }
    }
}
