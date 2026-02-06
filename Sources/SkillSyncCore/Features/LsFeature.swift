import Dependencies
import Foundation

public struct LsFeature {
  public struct SkillSummary: Equatable, Sendable {
    public var name: String
    public var state: String
    public var totalInvocations: Int
    public var positive: Int
    public var negative: Int

    public init(
      name: String,
      state: String,
      totalInvocations: Int,
      positive: Int,
      negative: Int
    ) {
      self.name = name
      self.state = state
      self.totalInvocations = totalInvocations
      self.positive = positive
      self.negative = negative
    }
  }

  public struct Result: Equatable, Sendable {
    public var skills: [SkillSummary]

    public init(skills: [SkillSummary]) {
      self.skills = skills
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run() throws -> Result {
    let skillsRoot = pathClient.skillsyncRoot().appendingPathComponent("skills", isDirectory: true)
    guard fileSystemClient.fileExists(skillsRoot.path), fileSystemClient.isDirectory(skillsRoot.path) else {
      return Result(skills: [])
    }

    let children = try fileSystemClient.contentsOfDirectory(skillsRoot)
      .filter { fileSystemClient.isDirectory($0.path) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    var summaries: [SkillSummary] = []
    for child in children {
      let summary = try loadSummary(for: child)
      summaries.append(summary)
    }

    return Result(skills: summaries)
  }

  private func loadSummary(for skillDirectory: URL) throws -> SkillSummary {
    let name = skillDirectory.lastPathComponent
    let metaURL = skillDirectory.appendingPathComponent(".meta.toml")

    var state = "active"
    var totalInvocations = 0
    var positive = 0
    var negative = 0

    if fileSystemClient.fileExists(metaURL.path), !fileSystemClient.isDirectory(metaURL.path) {
      let data = try fileSystemClient.data(metaURL)
      if let content = String(data: data, encoding: .utf8) {
        var currentSection = ""
        for rawLine in content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
          let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
          guard !line.isEmpty, !line.hasPrefix("#") else { continue }

          if line.hasPrefix("[") && line.hasSuffix("]") {
            currentSection = String(line.dropFirst().dropLast())
              .trimmingCharacters(in: .whitespacesAndNewlines)
            continue
          }

          guard let equals = line.firstIndex(of: "=") else { continue }
          let key = String(line[..<equals]).trimmingCharacters(in: .whitespacesAndNewlines)
          let rawValue = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespacesAndNewlines)

          switch (currentSection, key) {
          case ("skill", "state"):
            state = parseString(rawValue) ?? state
          case ("stats", "total-invocations"):
            totalInvocations = Int(rawValue) ?? totalInvocations
          case ("stats", "positive"):
            positive = Int(rawValue) ?? positive
          case ("stats", "negative"):
            negative = Int(rawValue) ?? negative
          default:
            continue
          }
        }
      }
    }

    return SkillSummary(
      name: name,
      state: state,
      totalInvocations: totalInvocations,
      positive: positive,
      negative: negative
    )
  }

  private func parseString(_ rawValue: String) -> String? {
    guard rawValue.count >= 2 else { return nil }
    if rawValue.hasPrefix("\""), rawValue.hasSuffix("\"") {
      return String(rawValue.dropFirst().dropLast())
    }
    if rawValue.hasPrefix("'"), rawValue.hasSuffix("'") {
      return String(rawValue.dropFirst().dropLast())
    }
    return nil
  }
}
