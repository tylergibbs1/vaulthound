import SwiftUI

/// Displays syntax-highlighted content. The expensive highlighting is computed
/// once in the initializer and cached, not recomputed on every body call.
struct SyntaxHighlightedView: View {
    private let highlighted: AttributedString

    init(content: String, contentType: String?) {
        highlighted = Self.highlight(content: content, contentType: contentType)
    }

    var body: some View {
        Text(highlighted)
            .font(.system(.body, design: .monospaced))
    }

    // MARK: - Static highlighting (computed once per init)

    private static func highlight(content: String, contentType: String?) -> AttributedString {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        let isJSON = contentType?.contains("json") == true
            || trimmed.first == "{"
            || trimmed.first == "["

        let isXML = contentType?.contains("xml") == true
            || trimmed.hasPrefix("<?xml")
            || trimmed.hasPrefix("<")

        if isJSON { return highlightJSON(content) }
        if isXML { return highlightXML(content) }
        return AttributedString(content)
    }

    private static func highlightJSON(_ content: String) -> AttributedString {
        let prettyContent: String
        if let data = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let formatted = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let str = String(data: formatted, encoding: .utf8) {
            prettyContent = str
        } else {
            prettyContent = content
        }

        var result = AttributedString()

        for line in prettyContent.components(separatedBy: .newlines) {
            var attrLine = AttributedString(line + "\n")
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Highlight JSON keys
            if let colonIdx = line.range(of: ":"),
               let quoteStart = line.firstIndex(of: "\"") {
                let afterQuote = line.index(after: quoteStart)
                if afterQuote < colonIdx.lowerBound,
                   let keyEnd = line[afterQuote...].firstIndex(of: "\"") {
                    let keyRange = quoteStart...keyEnd
                    if let attrRange = Range(NSRange(keyRange, in: line), in: attrLine) {
                        attrLine[attrRange].foregroundColor = .blue
                    }
                }
            }

            // Highlight booleans and null
            if trimmed.contains(":") {
                let stripped = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ","))
                if stripped.hasSuffix("true") || stripped.hasSuffix("false") {
                    let keyword = stripped.hasSuffix("true") ? "true" : "false"
                    if let range = attrLine.range(of: keyword) {
                        attrLine[range].foregroundColor = .orange
                    }
                } else if stripped.hasSuffix("null") {
                    if let range = attrLine.range(of: "null") {
                        attrLine[range].foregroundColor = .secondary
                    }
                }
            }

            result.append(attrLine)
        }

        return result
    }

    private static func highlightXML(_ content: String) -> AttributedString {
        var result = AttributedString()

        for line in content.components(separatedBy: .newlines) {
            var attrLine = AttributedString(line + "\n")

            var searchStart = line.startIndex
            while searchStart < line.endIndex,
                  let openBracket = line[searchStart...].firstIndex(of: "<") {
                guard let closeBracket = line[openBracket...].firstIndex(of: ">") else { break }
                let tagRange = openBracket...closeBracket

                if let attrRange = Range(NSRange(tagRange, in: line), in: attrLine) {
                    attrLine[attrRange].foregroundColor = .purple
                }

                searchStart = line.index(after: closeBracket)
            }

            result.append(attrLine)
        }

        return result
    }
}
