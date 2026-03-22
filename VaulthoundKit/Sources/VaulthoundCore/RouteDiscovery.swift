import Foundation
import VaulthoundModels

/// Discovers API routes from framework-specific file conventions.
///
/// Supported frameworks:
/// - Next.js App Router (`app/**/route.ts`)
/// - Next.js Pages Router (`pages/api/**/*.ts`)
/// - SvelteKit (`src/routes/**/+server.ts`)
/// - Nuxt (`server/api/**/*.ts`)
/// - Express/Fastify (basic `router.get/post` scanning)
///
/// Each discovered route includes the HTTP methods exported, the URL path
/// with dynamic segments converted to `{{PARAM}}` template variables,
/// and the source file for reference.
public struct RouteDiscovery {

    public struct DiscoveredRoute: Sendable {
        public var methods: [HTTPMethod]
        public var path: String              // e.g. "/api/users/{{id}}"
        public var sourceFile: String        // relative path from project root
        public var framework: Framework

        public init(methods: [HTTPMethod], path: String, sourceFile: String, framework: Framework) {
            self.methods = methods
            self.path = path
            self.sourceFile = sourceFile
            self.framework = framework
        }
    }

    public enum Framework: String, Sendable {
        case nextjsApp = "Next.js App Router"
        case nextjsPages = "Next.js Pages Router"
        case sveltekit = "SvelteKit"
        case nuxt = "Nuxt"
        case express = "Express/Fastify"
    }

    private let fileManager = FileManager.default

    public init() {}

    /// Discovers all API routes in a project directory.
    /// Returns routes grouped by framework detected.
    public func discover(at projectPath: String) -> [DiscoveredRoute] {
        let root = URL(filePath: projectPath)
        var routes: [DiscoveredRoute] = []

        // Next.js App Router: app/**/route.{ts,js}
        if fileManager.fileExists(atPath: root.appending(path: "app").path) {
            routes += scanNextjsAppRouter(root: root)
        }

        // Next.js Pages Router: pages/api/**/*.{ts,js}
        if fileManager.fileExists(atPath: root.appending(path: "pages/api").path) {
            routes += scanNextjsPagesRouter(root: root)
        }

        // Also check src/ variants
        if fileManager.fileExists(atPath: root.appending(path: "src/app").path) {
            routes += scanNextjsAppRouter(root: root, prefix: "src/app")
        }
        if fileManager.fileExists(atPath: root.appending(path: "src/pages/api").path) {
            routes += scanNextjsPagesRouter(root: root, prefix: "src/pages/api")
        }

        // SvelteKit: src/routes/**/+server.{ts,js}
        if fileManager.fileExists(atPath: root.appending(path: "src/routes").path) {
            routes += scanSvelteKit(root: root)
        }

        // Nuxt: server/api/**/*.{ts,js}
        if fileManager.fileExists(atPath: root.appending(path: "server/api").path) {
            routes += scanNuxt(root: root)
        }

        return routes
    }

    // MARK: - Next.js App Router

    /// Scans `app/**/route.{ts,js}` files and parses exported HTTP method functions.
    private func scanNextjsAppRouter(root: URL, prefix: String = "app") -> [DiscoveredRoute] {
        let appDir = root.appending(path: prefix)
        var routes: [DiscoveredRoute] = []

        findFiles(named: "route", extensions: ["ts", "js", "tsx", "jsx"], in: appDir) { fileURL in
            let relativePath = relativePath(of: fileURL, from: root)
            let routePath = extractRoutePath(from: relativePath, stripping: prefix, fileName: "route")
            let methods = parseExportedMethods(at: fileURL)

            if !methods.isEmpty {
                routes.append(DiscoveredRoute(
                    methods: methods,
                    path: routePath,
                    sourceFile: relativePath,
                    framework: .nextjsApp
                ))
            }
        }

        return routes
    }

    // MARK: - Next.js Pages Router

    /// Scans `pages/api/**/*.{ts,js}` and treats each file as a handler.
    private func scanNextjsPagesRouter(root: URL, prefix: String = "pages/api") -> [DiscoveredRoute] {
        let apiDir = root.appending(path: prefix)
        var routes: [DiscoveredRoute] = []

        findFiles(extensions: ["ts", "js", "tsx", "jsx"], in: apiDir) { fileURL in
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            // Skip non-route files
            guard fileName != "_middleware", !fileName.hasPrefix("_") else { return }

            let relativePath = relativePath(of: fileURL, from: root)
            let routePath = extractRoutePath(from: relativePath, stripping: prefix, fileName: nil)

            // Pages router: parse for req.method checks or export default
            let methods = parsePagesRouterMethods(at: fileURL)

            routes.append(DiscoveredRoute(
                methods: methods.isEmpty ? [.GET, .POST] : methods,
                path: routePath,
                sourceFile: relativePath,
                framework: .nextjsPages
            ))
        }

        return routes
    }

    // MARK: - SvelteKit

    /// Scans `src/routes/**/+server.{ts,js}` for exported method functions.
    private func scanSvelteKit(root: URL) -> [DiscoveredRoute] {
        let routesDir = root.appending(path: "src/routes")
        var routes: [DiscoveredRoute] = []

        findFiles(named: "+server", extensions: ["ts", "js"], in: routesDir) { fileURL in
            let relativePath = relativePath(of: fileURL, from: root)
            let routePath = extractRoutePath(from: relativePath, stripping: "src/routes", fileName: "+server")
            let methods = parseExportedMethods(at: fileURL)

            if !methods.isEmpty {
                routes.append(DiscoveredRoute(
                    methods: methods,
                    path: routePath,
                    sourceFile: relativePath,
                    framework: .sveltekit
                ))
            }
        }

        return routes
    }

    // MARK: - Nuxt

    /// Scans `server/api/**/*.{ts,js}` — Nuxt uses filename as route, method from `defineEventHandler`.
    private func scanNuxt(root: URL) -> [DiscoveredRoute] {
        let apiDir = root.appending(path: "server/api")
        var routes: [DiscoveredRoute] = []

        findFiles(extensions: ["ts", "js"], in: apiDir) { fileURL in
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            guard !fileName.hasPrefix("_") else { return }

            let relativePath = relativePath(of: fileURL, from: root)
            let routePath = extractRoutePath(from: relativePath, stripping: "server/api", fileName: nil)

            // Nuxt: check for method-specific filenames like users.get.ts, users.post.ts
            let methods = parseNuxtMethods(fileName: fileName)

            routes.append(DiscoveredRoute(
                methods: methods,
                path: routePath,
                sourceFile: relativePath,
                framework: .nuxt
            ))
        }

        return routes
    }

    // MARK: - File Parsing

    /// Parses `export async function GET/POST/PUT/PATCH/DELETE` from a file.
    /// Works for Next.js App Router and SvelteKit which use the same convention.
    private func parseExportedMethods(at fileURL: URL) -> [HTTPMethod] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }

        var methods: [HTTPMethod] = []
        let pattern = #"export\s+(?:async\s+)?function\s+(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsContent = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        for match in matches {
            let methodStr = nsContent.substring(with: match.range(at: 1))
            if let method = HTTPMethod(rawValue: methodStr) {
                methods.append(method)
            }
        }

        // Also check for `export { GET, POST }` re-export pattern
        let reexportPattern = #"export\s*\{[^}]*(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)[^}]*\}"#
        if let reexportRegex = try? NSRegularExpression(pattern: reexportPattern) {
            let reexportMatches = reexportRegex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
            for match in reexportMatches {
                for i in 1..<match.numberOfRanges {
                    let range = match.range(at: i)
                    guard range.location != NSNotFound else { continue }
                    let methodStr = nsContent.substring(with: range)
                    if let method = HTTPMethod(rawValue: methodStr), !methods.contains(method) {
                        methods.append(method)
                    }
                }
            }
        }

        return methods
    }

    /// Parses Pages Router files for `req.method === 'GET'` patterns.
    private func parsePagesRouterMethods(at fileURL: URL) -> [HTTPMethod] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }

        var methods: [HTTPMethod] = []
        let patterns = [
            #"req\.method\s*===?\s*['"](\w+)['"]"#,
            #"method\s*===?\s*['"](\w+)['"]"#,
        ]

        let nsContent = content as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
            for match in matches {
                let methodStr = nsContent.substring(with: match.range(at: 1))
                if let method = HTTPMethod(rawValue: methodStr.uppercased()), !methods.contains(method) {
                    methods.append(method)
                }
            }
        }

        return methods
    }

    /// Nuxt supports method-specific filenames: `users.get.ts`, `users.post.ts`.
    private func parseNuxtMethods(fileName: String) -> [HTTPMethod] {
        let parts = fileName.split(separator: ".")
        guard parts.count >= 2 else { return [.GET] }

        let lastPart = String(parts.last!).uppercased()
        if let method = HTTPMethod(rawValue: lastPart) {
            return [method]
        }

        return [.GET, .POST, .PUT, .PATCH, .DELETE]
    }

    // MARK: - Path Extraction

    /// Returns the path of `file` relative to `base`, standardizing both to handle symlinks.
    private func relativePath(of file: URL, from base: URL) -> String {
        let filePath = file.standardizedFileURL.path
        let basePath = base.standardizedFileURL.path
        if filePath.hasPrefix(basePath + "/") {
            return String(filePath.dropFirst(basePath.count + 1))
        }
        // Fallback: try resolving symlinks
        let resolvedFile = file.resolvingSymlinksInPath().path
        let resolvedBase = base.resolvingSymlinksInPath().path
        if resolvedFile.hasPrefix(resolvedBase + "/") {
            return String(resolvedFile.dropFirst(resolvedBase.count + 1))
        }
        return filePath
    }

    /// Converts a file path like `app/api/users/[id]/route.ts` to `/api/users/{{id}}`.
    private func extractRoutePath(from relativePath: String, stripping prefix: String, fileName: String?) -> String {
        var path = relativePath

        // Strip prefix (e.g. "app/" or "src/routes/")
        if path.hasPrefix(prefix + "/") {
            path = String(path.dropFirst(prefix.count + 1))
        }

        // Strip file name and extension
        if let fileName {
            // Strip "route.ts", "+server.ts", etc.
            for ext in ["ts", "js", "tsx", "jsx"] {
                path = path.replacingOccurrences(of: "/\(fileName).\(ext)", with: "")
                path = path.replacingOccurrences(of: "\(fileName).\(ext)", with: "")
            }
        } else {
            // Strip extension and extract directory + base name using string ops
            // (URL(filePath:) resolves relative paths to CWD which breaks things)
            let components = path.split(separator: "/")
            guard let lastComponent = components.last else { return "/" }
            let dir = components.dropLast().joined(separator: "/")

            // Strip all extensions: "users.get.ts" → "users", "[id].delete.ts" → "[id]"
            let nameWithoutExt = String(lastComponent).split(separator: ".").first.map(String.init)
                ?? String(lastComponent)

            if nameWithoutExt == "index" {
                path = dir
            } else {
                path = dir.isEmpty ? nameWithoutExt : "\(dir)/\(nameWithoutExt)"
            }
        }

        // Convert dynamic segments: [id] → {{id}}, [slug] → {{slug}}, [...rest] → {{rest}}
        // Next.js: [param], [[...catchAll]], [...slug]
        // SvelteKit: [param], [...rest]
        path = path.replacingOccurrences(of: "\\[\\[?\\.\\.\\.([^\\]]+)\\]\\]?", with: "{{$1}}", options: .regularExpression)
        path = path.replacingOccurrences(of: "\\[([^\\]]+)\\]", with: "{{$1}}", options: .regularExpression)

        // SvelteKit uses (group) directories for layout grouping — strip them
        path = path.replacingOccurrences(of: "\\([^)]+\\)/", with: "", options: .regularExpression)
        path = path.replacingOccurrences(of: "\\([^)]+\\)", with: "", options: .regularExpression)

        // Ensure leading slash, clean up double slashes
        if !path.hasPrefix("/") { path = "/" + path }
        while path.contains("//") { path = path.replacingOccurrences(of: "//", with: "/") }
        if path.count > 1 && path.hasSuffix("/") { path = String(path.dropLast()) }

        return path
    }

    // MARK: - File Walking

    private func findFiles(named name: String? = nil, extensions exts: [String], in directory: URL, handler: (URL) -> Void) {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let skipDirs: Set<String> = ["node_modules", ".next", ".svelte-kit", ".nuxt", ".output", "dist", "build", "__pycache__"]

        while let item = enumerator.nextObject() as? URL {
            let fileName = item.lastPathComponent

            // Skip build output directories
            if skipDirs.contains(fileName) {
                enumerator.skipDescendants()
                continue
            }

            guard let isFile = try? item.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile, isFile else { continue }

            let ext = item.pathExtension
            guard exts.contains(ext) else { continue }

            if let name {
                guard item.deletingPathExtension().lastPathComponent == name else { continue }
            }

            handler(item)
        }
    }
}
