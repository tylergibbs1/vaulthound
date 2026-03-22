import Testing
@testable import VaulthoundCore
import VaulthoundModels

@Suite("CurlParser")
struct CurlParserTests {
    let parser = CurlParser()

    @Test("Parses simple GET request")
    func simpleGet() {
        let result = parser.parse("curl https://api.example.com/users")
        #expect(result != nil)
        #expect(result?.method == .GET)
        #expect(result?.url == "https://api.example.com/users")
    }

    @Test("Parses POST with JSON body")
    func postWithBody() {
        let result = parser.parse(#"curl -X POST https://api.example.com/users -H "Content-Type: application/json" -d '{"name":"test"}'"#)
        #expect(result?.method == .POST)
        #expect(result?.bodyContent == #"{"name":"test"}"#)
        #expect(result?.bodyType == .json)
    }

    @Test("Parses headers")
    func headers() {
        let result = parser.parse(#"curl -H "Authorization: Bearer token123" -H "Accept: application/json" https://api.example.com"#)
        #expect(result?.headers.count == 2)
        #expect(result?.headers[0].key == "Authorization")
        #expect(result?.headers[0].value == "Bearer token123")
    }

    @Test("Infers POST when body is present without explicit method")
    func infersPost() {
        let result = parser.parse(#"curl https://api.example.com -d '{"key":"val"}'"#)
        #expect(result?.method == .POST)
    }

    @Test("Handles quoted URLs")
    func quotedUrl() {
        let result = parser.parse(#"curl "https://api.example.com/search?q=test""#)
        #expect(result?.url == "https://api.example.com/search?q=test")
    }

    @Test("Handles line continuations")
    func lineContinuation() {
        let result = parser.parse("""
        curl \\
          -X PUT \\
          https://api.example.com/users/1 \\
          -H "Content-Type: application/json"
        """)
        #expect(result?.method == .PUT)
        #expect(result?.url == "https://api.example.com/users/1")
    }

    @Test("Returns nil for empty input")
    func emptyInput() {
        let result = parser.parse("")
        #expect(result == nil)
    }

    @Test("Returns nil for input without URL")
    func noUrl() {
        let result = parser.parse("curl -X GET")
        #expect(result == nil)
    }

    @Test("Parses basic auth -u flag")
    func basicAuth() {
        let result = parser.parse(#"curl -u "user:pass" https://api.example.com"#)
        #expect(result?.headers.contains { $0.key == "Authorization" } == true)
    }
}
