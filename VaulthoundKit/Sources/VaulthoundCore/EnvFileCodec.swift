import Foundation

/// Parses and writes `.env` files.
///
/// Handles: comments (#), blank lines, quoted values (single/double),
/// `export` prefix, multiline values (double-quoted with \n escapes),
/// and inline comments after unquoted values.
public struct EnvFileCodec: Sendable {

    public struct Entry: Equatable, Sendable {
        public var key: String
        public var value: String
        public var isComment: Bool
        public var rawLine: String

        public init(key: String, value: String, isComment: Bool = false, rawLine: String = "") {
            self.key = key
            self.value = value
            self.isComment = isComment
            self.rawLine = rawLine
        }
    }

    public init() {}

    // MARK: - Parsing

    public func parse(_ content: String) -> [Entry] {
        var entries: [Entry] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                entries.append(Entry(key: "", value: "", isComment: false, rawLine: line))
                continue
            }

            if trimmed.hasPrefix("#") {
                entries.append(Entry(key: "", value: trimmed, isComment: true, rawLine: line))
                continue
            }

            guard let (key, value) = parseKeyValue(trimmed) else {
                entries.append(Entry(key: "", value: trimmed, isComment: true, rawLine: line))
                continue
            }

            entries.append(Entry(key: key, value: value, rawLine: line))
        }

        return entries
    }

    /// Parses just the key-value pairs, ignoring comments and blanks.
    public func parseVariables(_ content: String) -> [(key: String, value: String)] {
        parse(content)
            .filter { !$0.isComment && !$0.key.isEmpty }
            .map { ($0.key, $0.value) }
    }

    private func parseKeyValue(_ line: String) -> (String, String)? {
        var working = line

        // Strip optional `export ` prefix
        if working.hasPrefix("export ") {
            working = String(working.dropFirst(7))
        }

        guard let equalsIndex = working.firstIndex(of: "=") else { return nil }

        let key = String(working[working.startIndex..<equalsIndex]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, isValidKey(key) else { return nil }

        let rawValue = String(working[working.index(after: equalsIndex)...])
        let value = parseValue(rawValue)

        return (key, value)
    }

    private func isValidKey(_ key: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return key.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func parseValue(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty { return "" }

        // Double-quoted value
        if trimmed.hasPrefix("\"") {
            return parseQuotedValue(trimmed, quote: "\"")
        }

        // Single-quoted value (literal, no escape processing)
        if trimmed.hasPrefix("'") {
            return parseQuotedValue(trimmed, quote: "'")
        }

        // Unquoted: strip inline comment
        if let commentIndex = trimmed.range(of: " #") {
            return String(trimmed[trimmed.startIndex..<commentIndex.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        }

        return trimmed
    }

    private func parseQuotedValue(_ raw: String, quote: String) -> String {
        let inner = String(raw.dropFirst(quote.count))

        guard let endIndex = inner.range(of: quote)?.lowerBound else {
            // Unterminated quote — return everything after the opening quote
            return inner
        }

        let content = String(inner[inner.startIndex..<endIndex])

        if quote == "\"" {
            return content
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\t", with: "\t")
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }

        return content
    }

    // MARK: - Serialization

    public func serialize(_ entries: [Entry]) -> String {
        entries.map { entry in
            if entry.isComment { return entry.rawLine.isEmpty ? entry.value : entry.rawLine }
            if entry.key.isEmpty { return "" }
            let value = serializeValue(entry.value)
            return "\(entry.key)=\(value)"
        }.joined(separator: "\n")
    }

    /// Serializes just key-value pairs (no comments or blank lines preserved).
    public func serializeVariables(_ variables: [(key: String, value: String)]) -> String {
        variables.map { pair in
            "\(pair.key)=\(serializeValue(pair.value))"
        }.joined(separator: "\n")
    }

    private func serializeValue(_ value: String) -> String {
        if value.isEmpty { return "" }

        let needsQuoting = value.contains(" ")
            || value.contains("#")
            || value.contains("\"")
            || value.contains("'")
            || value.contains("\n")
            || value.contains("\t")
            || value.contains("\\")

        if needsQuoting {
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\t", with: "\\t")
            return "\"\(escaped)\""
        }

        return value
    }
}
