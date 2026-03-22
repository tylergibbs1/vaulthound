import Foundation
import VaulthoundModels

/// Scans directories for project roots by looking for marker files.
struct ProjectScanner {
    private let fileManager = FileManager.default

    /// Marker files that indicate a project root.
    private let projectMarkers: [(file: String, type: String)] = [
        ("Package.swift", "swift"),
        (".xcodeproj", "swift"),
        ("package.json", "node"),
        ("Cargo.toml", "rust"),
        ("pyproject.toml", "python"),
        ("setup.py", "python"),
        ("requirements.txt", "python"),
        ("go.mod", "go"),
        ("Gemfile", "ruby"),
        ("pom.xml", "java"),
        ("build.gradle", "java"),
    ]

    /// Scan the given directories for project roots.
    func scan(directories: [String]) -> [DiscoveredProject] {
        var results: [DiscoveredProject] = []

        for dir in directories {
            guard fileManager.fileExists(atPath: dir) else { continue }
            scanDirectory(dir, depth: 0, maxDepth: 3, into: &results)
        }

        return results
    }

    private func scanDirectory(_ path: String, depth: Int, maxDepth: Int, into results: inout [DiscoveredProject]) {
        guard depth <= maxDepth else { return }

        let url = URL(filePath: path)

        // Check if this is a project root
        if let project = detectProject(at: url) {
            results.append(project)
            return  // Don't recurse into detected projects
        }

        // Recurse into subdirectories
        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return }

        for item in contents {
            guard let isDir = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isDir else { continue }

            // Skip common non-project directories
            let name = item.lastPathComponent
            if ["node_modules", ".git", "build", "dist", ".build", "Pods", "DerivedData"].contains(name) {
                continue
            }

            scanDirectory(item.path, depth: depth + 1, maxDepth: maxDepth, into: &results)
        }
    }

    private func detectProject(at url: URL) -> DiscoveredProject? {
        var detectedType = "unknown"

        // Check for marker files
        var foundMarker = false
        for marker in projectMarkers {
            let markerPath = url.appending(path: marker.file).path
            if fileManager.fileExists(atPath: markerPath) {
                detectedType = marker.type
                foundMarker = true
                break
            }

            // Handle .xcodeproj which is a directory
            if marker.file == ".xcodeproj" {
                if let contents = try? fileManager.contentsOfDirectory(atPath: url.path),
                   contents.contains(where: { $0.hasSuffix(".xcodeproj") }) {
                    detectedType = marker.type
                    foundMarker = true
                    break
                }
            }
        }

        // Also accept directories with .git as project roots
        let hasGit = fileManager.fileExists(atPath: url.appending(path: ".git").path)
        guard foundMarker || hasGit else { return nil }

        // Find .env files
        let envFiles = findEnvFiles(in: url)

        // Check .gitignore protection
        let hasGitignoreProtection = checkGitignore(in: url)

        return DiscoveredProject(
            name: url.lastPathComponent,
            path: url.path,
            detectedType: detectedType,
            envFiles: envFiles,
            hasGitignoreProtection: hasGitignoreProtection
        )
    }

    private func findEnvFiles(in directory: URL) -> [String] {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return []
        }

        return contents.filter { name in
            name == ".env" ||
            name.hasPrefix(".env.") ||
            name == ".env.local" ||
            name == ".env.development" ||
            name == ".env.production" ||
            name == ".env.staging" ||
            name == ".env.example"
        }
    }

    private func checkGitignore(in directory: URL) -> Bool {
        let gitignorePath = directory.appending(path: ".gitignore").path
        guard let content = try? String(contentsOfFile: gitignorePath, encoding: .utf8) else {
            return false
        }

        let lines = content.components(separatedBy: .newlines)
        return lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed == ".env" || trimmed == ".env*" || trimmed == ".env.*" || trimmed == ".env.local"
        }
    }
}
