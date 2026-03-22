import Foundation
import VaulthoundCore

/// Daemon-side .env file parser.
struct EnvParser {

    struct ParsedEnvFile: Codable {
        var path: String
        var variables: [String: String]
    }

    func parse(filePath: String) -> ParsedEnvFile {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return ParsedEnvFile(path: filePath, variables: [:])
        }

        let codec = EnvFileCodec()
        let pairs = codec.parseVariables(content)
        let dict = Dictionary(uniqueKeysWithValues: pairs)

        return ParsedEnvFile(path: filePath, variables: dict)
    }

    /// Finds variables that exist in the example file but not in the actual env file.
    func findMissingVariables(envPath: String, examplePath: String) -> [String] {
        let envVars = parse(filePath: envPath).variables
        let exampleVars = parse(filePath: examplePath).variables

        return exampleVars.keys.filter { envVars[$0] == nil }.sorted()
    }
}
