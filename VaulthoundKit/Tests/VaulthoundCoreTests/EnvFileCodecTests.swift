import Testing
@testable import VaulthoundCore

@Suite("EnvFileCodec")
struct EnvFileCodecTests {
    let codec = EnvFileCodec()

    @Test("Parses simple key=value pairs")
    func simpleKeyValue() {
        let input = """
        FOO=bar
        BAZ=qux
        """
        let vars = codec.parseVariables(input)
        #expect(vars.count == 2)
        #expect(vars[0].key == "FOO")
        #expect(vars[0].value == "bar")
        #expect(vars[1].key == "BAZ")
        #expect(vars[1].value == "qux")
    }

    @Test("Handles double-quoted values with escape sequences")
    func doubleQuotedValues() {
        let input = #"MESSAGE="hello\nworld""#
        let vars = codec.parseVariables(input)
        #expect(vars.count == 1)
        #expect(vars[0].value == "hello\nworld")
    }

    @Test("Handles single-quoted values literally")
    func singleQuotedValues() {
        let input = #"MESSAGE='hello\nworld'"#
        let vars = codec.parseVariables(input)
        #expect(vars.count == 1)
        #expect(vars[0].value == #"hello\nworld"#)
    }

    @Test("Strips export prefix")
    func exportPrefix() {
        let input = "export API_KEY=secret123"
        let vars = codec.parseVariables(input)
        #expect(vars.count == 1)
        #expect(vars[0].key == "API_KEY")
        #expect(vars[0].value == "secret123")
    }

    @Test("Ignores comments and blank lines")
    func commentsAndBlanks() {
        let input = """
        # This is a comment
        FOO=bar

        # Another comment
        BAZ=qux
        """
        let vars = codec.parseVariables(input)
        #expect(vars.count == 2)
    }

    @Test("Handles inline comments after unquoted values")
    func inlineComments() {
        let input = "FOO=bar # this is a comment"
        let vars = codec.parseVariables(input)
        #expect(vars[0].value == "bar")
    }

    @Test("Preserves inline # in quoted values")
    func hashInQuotedValues() {
        let input = #"URL="https://example.com/#fragment""#
        let vars = codec.parseVariables(input)
        #expect(vars[0].value == "https://example.com/#fragment")
    }

    @Test("Handles empty values")
    func emptyValues() {
        let input = "EMPTY="
        let vars = codec.parseVariables(input)
        #expect(vars[0].value == "")
    }

    @Test("Roundtrip: parse then serialize preserves key-value pairs")
    func roundtrip() {
        let input = """
        FOO=bar
        SECRET=sk-abc123
        URL=https://example.com
        """
        let vars = codec.parseVariables(input)
        let output = codec.serializeVariables(vars)
        let reparsed = codec.parseVariables(output)
        #expect(vars.count == reparsed.count)
        for (a, b) in zip(vars, reparsed) {
            #expect(a.key == b.key)
            #expect(a.value == b.value)
        }
    }

    @Test("Serializes values needing quoting")
    func serializesQuotedValues() {
        let vars = [
            (key: "SIMPLE", value: "hello"),
            (key: "SPACED", value: "hello world"),
            (key: "NEWLINE", value: "line1\nline2"),
        ]
        let output = codec.serializeVariables(vars)
        #expect(output.contains("SIMPLE=hello"))
        #expect(output.contains(#"SPACED="hello world""#))
        #expect(output.contains(#"NEWLINE="line1\nline2""#))
    }

    @Test("Rejects invalid key names")
    func invalidKeys() {
        let input = "invalid-key=value"
        let vars = codec.parseVariables(input)
        #expect(vars.isEmpty)
    }
}
