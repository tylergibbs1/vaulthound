import Foundation

/// Checks if a given file is covered by the project's .gitignore.
struct GitignoreChecker {

    /// Returns true if the given file name appears to be ignored by .gitignore.
    func isIgnored(fileName: String, in projectPath: String) -> Bool {
        let gitignorePath = URL(filePath: projectPath).appending(path: ".gitignore").path

        guard let content = try? String(contentsOfFile: gitignorePath, encoding: .utf8) else {
            return false
        }

        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        for pattern in lines {
            if matchesGitignorePattern(fileName: fileName, pattern: pattern) {
                return true
            }
        }

        return false
    }

    private func matchesGitignorePattern(fileName: String, pattern: String) -> Bool {
        // Exact match
        if pattern == fileName { return true }

        // Wildcard patterns
        if pattern == ".env*" && fileName.hasPrefix(".env") { return true }
        if pattern == ".env.*" && fileName.hasPrefix(".env.") { return true }

        // Directory glob
        if pattern.hasSuffix("/") && fileName.hasPrefix(String(pattern.dropLast())) { return true }

        // Simple star glob
        if pattern.contains("*") {
            let parts = pattern.split(separator: "*", maxSplits: 1)
            if parts.count == 2 {
                let prefix = String(parts[0])
                let suffix = String(parts[1])
                if fileName.hasPrefix(prefix) && fileName.hasSuffix(suffix) { return true }
            } else if parts.count == 1 {
                let prefix = String(parts[0])
                if fileName.hasPrefix(prefix) { return true }
            }
        }

        return false
    }
}
