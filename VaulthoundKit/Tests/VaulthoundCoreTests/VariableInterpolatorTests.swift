import Testing
@testable import VaulthoundCore

@Suite("VariableInterpolator")
struct VariableInterpolatorTests {
    let interpolator = VariableInterpolator()

    @Test("Resolves simple placeholders")
    func simplePlaceholders() {
        let result = interpolator.resolve(
            "https://{{HOST}}/api/{{VERSION}}",
            using: ["HOST": "example.com", "VERSION": "v1"]
        )
        #expect(result == "https://example.com/api/v1")
    }

    @Test("Leaves unresolved placeholders as-is")
    func unresolvedPlaceholders() {
        let result = interpolator.resolve(
            "{{BASE_URL}}/{{MISSING}}",
            using: ["BASE_URL": "https://example.com"]
        )
        #expect(result == "https://example.com/{{MISSING}}")
    }

    @Test("Handles placeholders with whitespace")
    func whitespacePlaceholders() {
        let result = interpolator.resolve(
            "{{ HOST }}",
            using: ["HOST": "example.com"]
        )
        #expect(result == "example.com")
    }

    @Test("Returns original string when no placeholders")
    func noPlaceholders() {
        let result = interpolator.resolve(
            "https://example.com/api",
            using: ["HOST": "other.com"]
        )
        #expect(result == "https://example.com/api")
    }

    @Test("Extracts variable names from template")
    func extractVariableNames() {
        let names = interpolator.extractVariableNames(
            from: "{{BASE_URL}}/users/{{USER_ID}}?key={{API_KEY}}"
        )
        #expect(names == ["BASE_URL", "USER_ID", "API_KEY"])
    }

    @Test("containsPlaceholders returns correct results")
    func containsPlaceholders() {
        #expect(interpolator.containsPlaceholders("{{FOO}}"))
        #expect(!interpolator.containsPlaceholders("plain text"))
        #expect(!interpolator.containsPlaceholders("just {{ without closing"))
    }

    @Test("Handles multiple occurrences of the same variable")
    func multipleOccurrences() {
        let result = interpolator.resolve(
            "{{HOST}} and {{HOST}} again",
            using: ["HOST": "x"]
        )
        #expect(result == "x and x again")
    }

    @Test("Handles empty variables dictionary")
    func emptyDictionary() {
        let result = interpolator.resolve("{{FOO}}", using: [:])
        #expect(result == "{{FOO}}")
    }
}
