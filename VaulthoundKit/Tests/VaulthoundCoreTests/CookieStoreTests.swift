import Testing
import Foundation
@testable import VaulthoundCore

@Suite("CookieStore")
struct CookieStoreTests {
    @Test("Processes Set-Cookie and generates Cookie header")
    func roundtrip() {
        let store = CookieStore()
        let url = URL(string: "https://example.com/api")!

        store.processSetCookieHeaders([
            "session=abc123; Path=/; HttpOnly",
            "theme=dark; Path=/; Max-Age=3600",
        ], for: url)

        let header = store.cookieHeader(for: url)
        #expect(header != nil)
        #expect(header!.contains("session=abc123"))
        #expect(header!.contains("theme=dark"))
    }

    @Test("Respects domain matching")
    func domainMatching() {
        let store = CookieStore()
        let url = URL(string: "https://api.example.com/data")!

        store.processSetCookieHeaders([
            "token=xyz; Domain=example.com; Path=/",
        ], for: url)

        // Should match subdomain
        let header = store.cookieHeader(for: url)
        #expect(header?.contains("token=xyz") == true)

        // Should not match different domain
        let otherURL = URL(string: "https://other.com/data")!
        #expect(store.cookieHeader(for: otherURL) == nil)
    }

    @Test("Respects secure flag")
    func secureFlag() {
        let store = CookieStore()
        let httpsURL = URL(string: "https://example.com/api")!

        store.processSetCookieHeaders([
            "secure_token=abc; Secure; Path=/",
        ], for: httpsURL)

        #expect(store.cookieHeader(for: httpsURL)?.contains("secure_token") == true)

        let httpURL = URL(string: "http://example.com/api")!
        #expect(store.cookieHeader(for: httpURL) == nil)
    }

    @Test("Replaces existing cookie with same name and path")
    func replacesCookie() {
        let store = CookieStore()
        let url = URL(string: "https://example.com/")!

        store.processSetCookieHeaders(["token=old"], for: url)
        store.processSetCookieHeaders(["token=new"], for: url)

        let header = store.cookieHeader(for: url)
        #expect(header == "token=new")
    }

    @Test("Clear removes cookies for domain")
    func clearDomain() {
        let store = CookieStore()
        let url = URL(string: "https://example.com/")!

        store.processSetCookieHeaders(["token=abc"], for: url)
        store.clearCookies(for: "example.com")
        #expect(store.cookieHeader(for: url) == nil)
    }

    @Test("ClearAll removes everything")
    func clearAll() {
        let store = CookieStore()

        store.processSetCookieHeaders(["a=1"], for: URL(string: "https://one.com/")!)
        store.processSetCookieHeaders(["b=2"], for: URL(string: "https://two.com/")!)

        store.clearAll()

        #expect(store.cookieHeader(for: URL(string: "https://one.com/")!) == nil)
        #expect(store.cookieHeader(for: URL(string: "https://two.com/")!) == nil)
    }
}
