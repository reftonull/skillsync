import Dependencies
import Foundation

public struct LsFeature {
  public struct SkillSummary: Equatable, Sendable, Encodable {
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

  public struct Result: Equatable, Sendable, Encodable {
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
    let meta = try UpdateMetaFeature().read(metaURL: metaURL)

    return SkillSummary(
      name: name,
      state: meta.string(section: "skill", key: "state") ?? "active",
      totalInvocations: meta.int(section: "stats", key: "total-invocations") ?? 0,
      positive: meta.int(section: "stats", key: "positive") ?? 0,
      negative: meta.int(section: "stats", key: "negative") ?? 0
    )
  }
}
