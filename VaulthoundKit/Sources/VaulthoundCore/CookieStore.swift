import Foundation

/// In-memory cookie store that handles Set-Cookie parsing and Cookie header generation.
/// Persistence is handled by the caller via CookieJar SwiftData model.
public final class CookieStore: @unchecked Sendable {

    public struct Cookie: Sendable {
        public var name: String
        public var value: String
        public var domain: String
        public var path: String
        public var expiresAt: Date?
        public var isSecure: Bool
        public var isHTTPOnly: Bool

        public var isExpired: Bool {
            guard let expiresAt else { return false }
            return expiresAt < Date.now
        }
    }

    private var cookies: [String: [Cookie]] = [:]  // domain -> cookies
    private let lock = NSLock()

    public init() {}

    // MARK: - Set-Cookie Parsing

    public func processSetCookieHeaders(_ headers: [String], for url: URL) {
        lock.lock()
        defer { lock.unlock() }

        for header in headers {
            guard let cookie = parseSetCookie(header, url: url) else { continue }
            var domainCookies = cookies[cookie.domain, default: []]

            // Replace existing cookie with same name+path
            domainCookies.removeAll { $0.name == cookie.name && $0.path == cookie.path }
            domainCookies.append(cookie)
            cookies[cookie.domain] = domainCookies
        }
    }

    // MARK: - Cookie Header Generation

    public func cookieHeader(for url: URL) -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard let host = url.host else { return nil }

        let matching = cookies.flatMap { domain, cookies in
            cookies.filter { cookie in
                matchesDomain(host: host, cookieDomain: domain)
                    && url.path.hasPrefix(cookie.path)
                    && !cookie.isExpired
                    && (!cookie.isSecure || url.scheme == "https")
            }
        }

        guard !matching.isEmpty else { return nil }
        return matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    // MARK: - Management

    public func allCookies(for domain: String) -> [Cookie] {
        lock.lock()
        defer { lock.unlock() }
        return cookies[domain, default: []].filter { !$0.isExpired }
    }

    public func clearCookies(for domain: String) {
        lock.lock()
        defer { lock.unlock() }
        cookies.removeValue(forKey: domain)
    }

    public func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        cookies.removeAll()
    }

    // MARK: - Private

    private func parseSetCookie(_ header: String, url: URL) -> Cookie? {
        let parts = header.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = parts.first else { return nil }

        guard let equalsIndex = first.firstIndex(of: "=") else { return nil }
        let name = String(first[first.startIndex..<equalsIndex])
        let value = String(first[first.index(after: equalsIndex)...])

        var domain = url.host ?? ""
        var path = "/"
        var expiresAt: Date?
        var isSecure = false
        var isHTTPOnly = false

        for attribute in parts.dropFirst() {
            let lower = attribute.lowercased()

            if lower.hasPrefix("domain=") {
                domain = String(attribute.dropFirst(7)).trimmingCharacters(in: CharacterSet(charactersIn: "."))
            } else if lower.hasPrefix("path=") {
                path = String(attribute.dropFirst(5))
            } else if lower.hasPrefix("expires=") {
                let dateStr = String(attribute.dropFirst(8))
                expiresAt = parseHTTPDate(dateStr)
            } else if lower.hasPrefix("max-age=") {
                if let seconds = Double(String(attribute.dropFirst(8))) {
                    expiresAt = Date.now.addingTimeInterval(seconds)
                }
            } else if lower == "secure" {
                isSecure = true
            } else if lower == "httponly" {
                isHTTPOnly = true
            }
        }

        return Cookie(
            name: name, value: value, domain: domain, path: path,
            expiresAt: expiresAt, isSecure: isSecure, isHTTPOnly: isHTTPOnly
        )
    }

    private func matchesDomain(host: String, cookieDomain: String) -> Bool {
        host == cookieDomain || host.hasSuffix(".\(cookieDomain)")
    }

    private func parseHTTPDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // RFC 7231 format
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = formatter.date(from: string) { return date }

        // RFC 850 format
        formatter.dateFormat = "EEEE, dd-MMM-yy HH:mm:ss zzz"
        if let date = formatter.date(from: string) { return date }

        return nil
    }
}
