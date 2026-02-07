import Dependencies
import Foundation

public struct LoadSyncConfigFeature {
  public struct Result: Equatable, Sendable {
    public var targets: [SyncTarget]
    public var observation: ObservationSettings

    public init(
      targets: [SyncTarget],
      observation: ObservationSettings = .default
    ) {
      self.targets = targets
      self.observation = observation
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run() throws -> Result {
    let configPath = pathClient.skillsyncRoot().appendingPathComponent("config.toml")

    guard fileSystemClient.fileExists(configPath.path) else {
      return Result(targets: [], observation: .default)
    }

    let data = try fileSystemClient.data(configPath)
    guard let contents = String(data: data, encoding: .utf8) else {
      return Result(targets: [], observation: .default)
    }

    return Result(
      targets: Self.parseTargets(from: contents),
      observation: Self.parseObservationSettings(from: contents)
    )
  }

  static func parseTargets(from contents: String) -> [SyncTarget] {
    var targets: [SyncTarget] = []
    var current: [String: String] = [:]
    var inTargetsArray = false

    func flushCurrentTarget() {
      guard !current.isEmpty else { return }
      defer { current = [:] }
      guard
        let idRaw = current["id"],
        let pathRaw = current["path"],
        let sourceRaw = current["source"],
        let id = parseStringLiteral(idRaw),
        let path = parseStringLiteral(pathRaw),
        let sourceString = parseStringLiteral(sourceRaw),
        let source = SyncTarget.Source(rawValue: sourceString)
      else {
        return
      }
      targets.append(.init(id: id, path: path, source: source))
    }

    for rawLine in contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
      let line = Self.stripComments(String(rawLine)).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }

      if line.hasPrefix("[[") && line.hasSuffix("]]") {
        let section = String(line.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        if section == "targets" {
          flushCurrentTarget()
          inTargetsArray = true
          continue
        }
        flushCurrentTarget()
        inTargetsArray = false
        continue
      }

      if line.hasPrefix("[") && line.hasSuffix("]") {
        flushCurrentTarget()
        inTargetsArray = false
        continue
      }

      guard inTargetsArray else { continue }
      guard let equals = line.firstIndex(of: "=") else { continue }
      let key = String(line[..<equals]).trimmingCharacters(in: .whitespacesAndNewlines)
      let value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !key.isEmpty else { continue }
      current[key] = value
    }

    flushCurrentTarget()
    return targets
  }

  static func parseObservationSettings(from contents: String) -> ObservationSettings {
    var mode = ObservationSettings.default.mode
    var inObservationSection = false

    for rawLine in contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
      let line = Self.stripComments(String(rawLine)).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }

      if line.hasPrefix("[") && line.hasSuffix("]") {
        let section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        inObservationSection = section == "observation"
        continue
      }

      guard inObservationSection else { continue }
      guard let equalsIndex = line.firstIndex(of: "=") else { continue }

      let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
      let rawValue = String(line[line.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

      switch key {
      case "mode":
        if let rawMode = Self.parseStringLiteral(rawValue), let parsedMode = ObservationMode(rawValue: rawMode) {
          mode = parsedMode
        }
      default:
        continue
      }
    }

    return ObservationSettings(mode: mode)
  }

  private static func stripComments(_ line: String) -> String {
    var inString = false
    var delimiter: Character?
    var output = ""

    for character in line {
      if inString {
        output.append(character)
        if character == delimiter {
          inString = false
          delimiter = nil
        }
      } else if character == "\"" || character == "'" {
        inString = true
        delimiter = character
        output.append(character)
      } else if character == "#" {
        break
      } else {
        output.append(character)
      }
    }

    return output
  }

  static func parseStringLiteral(_ rawValue: String) -> String? {
    guard let first = rawValue.first, let last = rawValue.last else { return nil }
    guard (first == "\"" && last == "\"") || (first == "'" && last == "'") else { return nil }
    return String(rawValue.dropFirst().dropLast())
  }
}
