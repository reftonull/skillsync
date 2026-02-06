import Dependencies
import Foundation

public struct LoadSyncConfigFeature {
  public struct Result: Equatable, Sendable {
    public var configuredTools: [String: String]

    public init(configuredTools: [String: String]) {
      self.configuredTools = configuredTools
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run() throws -> Result {
    let configPath = pathClient.skillsyncRoot()
      .appendingPathComponent("config.toml")

    guard fileSystemClient.fileExists(configPath.path) else {
      return Result(configuredTools: [:])
    }

    let data = try fileSystemClient.data(configPath)
    guard let contents = String(data: data, encoding: .utf8) else {
      return Result(configuredTools: [:])
    }

    return Result(configuredTools: Self.parseConfiguredTools(from: contents))
  }

  static func parseConfiguredTools(from contents: String) -> [String: String] {
    var configuredTools: [String: String] = [:]
    var currentTool: String?

    for rawLine in contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
      let line = Self.stripComments(String(rawLine)).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }

      if line.hasPrefix("[") && line.hasSuffix("]") {
        let section = String(
          line
          .dropFirst()
          .dropLast()
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        if section.hasPrefix("tools.") {
          let name = String(section.dropFirst("tools.".count))
          currentTool = name.isEmpty ? nil : name
        } else {
          currentTool = nil
        }
        continue
      }

      guard let currentTool else { continue }
      guard let equalsIndex = line.firstIndex(of: "=") else { continue }

      let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
      let rawValue = String(line[line.index(after: equalsIndex)...])
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard key == "path" else { continue }
      guard let parsedPath = Self.parseStringLiteral(rawValue) else { continue }

      configuredTools[currentTool] = parsedPath
    }

    return configuredTools
  }

  private static func stripComments(_ line: String) -> String {
    var inString = false
    var delimiter: Character?
    var result = ""

    for character in line {
      if inString {
        result.append(character)
        if character == delimiter {
          inString = false
          delimiter = nil
        }
      } else if character == "\"" || character == "'" {
        inString = true
        delimiter = character
        result.append(character)
      } else if character == "#" {
        break
      } else {
        result.append(character)
      }
    }

    return result
  }

  private static func parseStringLiteral(_ rawValue: String) -> String? {
    guard let first = rawValue.first, let last = rawValue.last else { return nil }
    guard (first == "\"" && last == "\"") || (first == "'" && last == "'") else { return nil }
    return String(rawValue.dropFirst().dropLast())
  }
}
