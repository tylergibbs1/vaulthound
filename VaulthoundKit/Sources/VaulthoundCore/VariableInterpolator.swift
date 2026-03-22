import Foundation

/// Resolves `{{VARIABLE_NAME}}` placeholders in a template string.
///
/// This is a pure function with no side effects. The caller is responsible
/// for building the variables dictionary (including resolving secrets from Keychain).
public struct VariableInterpolator: Sendable {

    public init() {}

    /// Resolves all `{{KEY}}` placeholders using the provided dictionary.
    /// Unresolved placeholders are left as-is.
    public func resolve(_ template: String, using variables: [String: String]) -> String {
        var result = template
        let pattern = "\\{\\{\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*\\}\\}"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return template
        }

        let nsRange = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, range: nsRange)

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: result),
                  let keyRange = Range(match.range(at: 1), in: result) else {
                continue
            }

            let key = String(result[keyRange])
            if let value = variables[key] {
                result.replaceSubrange(fullRange, with: value)
            }
        }

        return result
    }

    /// Extracts all variable names referenced in a template.
    public func extractVariableNames(from template: String) -> [String] {
        let pattern = "\\{\\{\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*\\}\\}"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(template.startIndex..., in: template)
        let matches = regex.matches(in: template, range: nsRange)

        return matches.compactMap { match in
            guard let keyRange = Range(match.range(at: 1), in: template) else { return nil }
            return String(template[keyRange])
        }
    }

    /// Returns true if the template contains any `{{...}}` placeholders.
    public func containsPlaceholders(_ template: String) -> Bool {
        template.contains("{{") && template.contains("}}")
    }
}
