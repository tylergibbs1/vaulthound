import Testing
import Foundation
@testable import VaulthoundCore
import VaulthoundModels

@Suite("PostmanV21Parser")
struct PostmanV21ParserTests {
    let parser = PostmanV21Parser()

    @Test("Parses collection name from info block")
    func parsesCollectionName() throws {
        let json = """
        {
            "info": { "name": "My API", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json" },
            "item": []
        }
        """.data(using: .utf8)!

        let result = try parser.parse(json)
        #expect(result.name == "My API")
        #expect(result.requests.isEmpty)
    }

    @Test("Parses GET request with URL string")
    func parsesGetRequest() throws {
        let json = """
        {
            "info": { "name": "Test" },
            "item": [{
                "name": "Get Users",
                "request": {
                    "method": "GET",
                    "url": "https://api.example.com/users"
                }
            }]
        }
        """.data(using: .utf8)!

        let result = try parser.parse(json)
        #expect(result.requests.count == 1)
        #expect(result.requests[0].name == "Get Users")
        #expect(result.requests[0].method == .GET)
        #expect(result.requests[0].url == "https://api.example.com/users")
    }

    @Test("Parses POST request with headers and JSON body")
    func parsesPostWithBody() throws {
        let json = """
        {
            "info": { "name": "Test" },
            "item": [{
                "name": "Create User",
                "request": {
                    "method": "POST",
                    "url": { "raw": "https://api.example.com/users" },
                    "header": [
                        { "key": "Content-Type", "value": "application/json" },
                        { "key": "Authorization", "value": "Bearer token", "disabled": true }
                    ],
                    "body": {
                        "mode": "raw",
                        "raw": "{\\"name\\": \\"test\\"}",
                        "options": { "raw": { "language": "json" } }
                    }
                }
            }]
        }
        """.data(using: .utf8)!

        let result = try parser.parse(json)
        let req = result.requests[0]
        #expect(req.method == .POST)
        #expect(req.headers.count == 2)
        #expect(req.headers[0].isEnabled == true)
        #expect(req.headers[1].isEnabled == false)
        #expect(req.bodyType == .json)
        #expect(req.bodyContent?.contains("name") == true)
    }

    @Test("Parses nested folders into flat request list")
    func parsesNestedFolders() throws {
        let json = """
        {
            "info": { "name": "Nested" },
            "item": [{
                "name": "Auth",
                "item": [{
                    "name": "Login",
                    "request": { "method": "POST", "url": "https://api.example.com/auth/login" }
                }, {
                    "name": "Refresh",
                    "request": { "method": "POST", "url": "https://api.example.com/auth/refresh" }
                }]
            }, {
                "name": "Users",
                "item": [{
                    "name": "List",
                    "request": { "method": "GET", "url": "https://api.example.com/users" }
                }]
            }]
        }
        """.data(using: .utf8)!

        let result = try parser.parse(json)
        #expect(result.requests.count == 3)
        #expect(result.requests[0].folderPath == ["Auth"])
        #expect(result.requests[2].folderPath == ["Users"])
    }

    @Test("Parses URL from components when raw is missing")
    func parsesUrlComponents() throws {
        let json = """
        {
            "info": { "name": "Test" },
            "item": [{
                "name": "Test",
                "request": {
                    "method": "GET",
                    "url": {
                        "protocol": "https",
                        "host": ["api", "example", "com"],
                        "path": ["v1", "users"]
                    }
                }
            }]
        }
        """.data(using: .utf8)!

        let result = try parser.parse(json)
        #expect(result.requests[0].url == "https://api.example.com/v1/users")
    }

    @Test("Parses form-urlencoded body")
    func parsesFormBody() throws {
        let json = """
        {
            "info": { "name": "Test" },
            "item": [{
                "name": "Login",
                "request": {
                    "method": "POST",
                    "url": "https://example.com/login",
                    "body": {
                        "mode": "urlencoded",
                        "urlencoded": [
                            { "key": "username", "value": "admin" },
                            { "key": "password", "value": "secret" }
                        ]
                    }
                }
            }]
        }
        """.data(using: .utf8)!

        let result = try parser.parse(json)
        #expect(result.requests[0].bodyType == .formData)
        #expect(result.requests[0].bodyContent == "username=admin&password=secret")
    }

    @Test("Throws on invalid JSON")
    func throwsOnInvalid() {
        let badData = "not json".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try parser.parse(badData)
        }
    }
}
