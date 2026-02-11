import Dependencies
import Foundation

public struct UpdateFeature {
  public struct Input: Equatable, Sendable {
    public var name: String
    public var force: Bool

    public init(name: String, force: Bool = false) {
      self.name = name
      self.force = force
    }
  }

  public struct Result: Equatable, Sendable {
    public var name: String
    public var skillRoot: URL
    public var updated: Bool
    public var contentHash: String

    public init(name: String, skillRoot: URL, updated: Bool, contentHash: String) {
      self.name = name
      self.skillRoot = skillRoot
      self.updated = updated
      self.contentHash = contentHash
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case skillNotFound(String)
    case notGitHubManaged(String)
    case missingUpstreamMetadata(String)
    case localSkillDiverged(String)
    case invalidGitHubSkillPath(String)
    case missingSkillMarkdown(String)

    public var description: String {
      switch self {
      case let .skillNotFound(name):
        return "Skill '\(name)' not found."
      case let .notGitHubManaged(name):
        return "Skill '\(name)' is not managed from GitHub."
      case let .missingUpstreamMetadata(name):
        return "Skill '\(name)' is missing upstream metadata."
      case let .localSkillDiverged(name):
        return "Skill '\(name)' has local changes and diverged from upstream."
      case let .invalidGitHubSkillPath(path):
        return "Invalid file path in GitHub skill payload: \(path)"
      case let .missingSkillMarkdown(path):
        return "Skill directory '\(path)' must contain SKILL.md."
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient
  @Dependency(\.githubSkillClient) var githubSkillClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let skillRoot = pathClient.skillsyncRoot()
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(input.name, isDirectory: true)
    guard fileSystemClient.fileExists(skillRoot.path), fileSystemClient.isDirectory(skillRoot.path) else {
      throw Error.skillNotFound(input.name)
    }

    let metaURL = skillRoot.appendingPathComponent(".meta.toml")
    let meta = try UpdateMetaFeature().read(metaURL: metaURL)

    guard meta.string(section: "skill", key: "source") == "github" else {
      throw Error.notGitHubManaged(input.name)
    }

    guard
      let repo = meta.string(section: "upstream", key: "repo"),
      let skillPath = meta.string(section: "upstream", key: "skill-path"),
      let ref = meta.string(section: "upstream", key: "ref")
    else {
      throw Error.missingUpstreamMetadata(input.name)
    }

    let githubSource = try GitHubSkillSource(repo: repo, skillPath: skillPath, ref: ref)

    // We intentionally check divergence before fetching so we can fail fast
    // without network calls when local edits already block an update.
    let currentHash = try SkillContentHashFeature().run(skillDirectory: skillRoot)
    let baseHash = meta.string(section: "upstream", key: "base-content-hash")
      ?? meta.string(section: "skill", key: "content-hash")
      ?? ""
    guard input.force || currentHash == baseHash else {
      throw Error.localSkillDiverged(input.name)
    }

    let fetched = try githubSkillClient.fetch(githubSource)
    guard fetched.files["SKILL.md"] != nil else {
      throw Error.missingSkillMarkdown(skillPath)
    }

    var sanitizedFiles: [String: Data] = [:]
    for key in fetched.files.keys.sorted() {
      guard let sanitized = SkillRelativePath.sanitize(key) else {
        throw Error.invalidGitHubSkillPath(key)
      }
      if sanitized == ".meta.toml" {
        continue
      }
      guard let data = fetched.files[key] else { continue }
      sanitizedFiles[sanitized] = data
    }

    let upstreamHash = SkillContentHashFeature.hash(files: sanitizedFiles)
    // Content can be identical even when upstream ref/commit metadata changed.
    // In that case we refresh upstream tracking fields but keep `updated = false`.
    if upstreamHash == currentHash {
      var updates: [UpdateMetaFeature.FieldUpdate] = [
        .init(section: "upstream", key: "ref", operation: .setString(fetched.resolvedRef)),
        .init(section: "upstream", key: "commit", operation: .setString(fetched.commit)),
      ]
      if input.force, baseHash != currentHash {
        updates.append(.init(section: "skill", key: "content-hash", operation: .setString(currentHash)))
        updates.append(.init(section: "upstream", key: "base-content-hash", operation: .setString(currentHash)))
      }
      try UpdateMetaFeature().run(metaURL: metaURL, updates: updates)
      return Result(name: input.name, skillRoot: skillRoot, updated: false, contentHash: currentHash)
    }

    try replaceSkillFiles(skillRoot: skillRoot, files: sanitizedFiles)

    let contentHash = try SkillContentHashFeature().run(skillDirectory: skillRoot)
    try UpdateMetaFeature().run(
      metaURL: metaURL,
      updates: [
        .init(section: "skill", key: "content-hash", operation: .setString(contentHash)),
        .init(section: "skill", key: "version", operation: .incrementInt(1)),
        .init(section: "upstream", key: "ref", operation: .setString(fetched.resolvedRef)),
        .init(section: "upstream", key: "commit", operation: .setString(fetched.commit)),
        .init(section: "upstream", key: "base-content-hash", operation: .setString(contentHash)),
      ]
    )

    return Result(name: input.name, skillRoot: skillRoot, updated: true, contentHash: contentHash)
  }

  private func replaceSkillFiles(skillRoot: URL, files: [String: Data]) throws {
    let children = try fileSystemClient.contentsOfDirectory(skillRoot)
    for child in children where child.lastPathComponent != ".meta.toml" {
      try fileSystemClient.removeItem(child)
    }

    for relativePath in files.keys.sorted() {
      guard let data = files[relativePath] else { continue }
      let destination = skillRoot.appendingPathComponent(relativePath)
      try fileSystemClient.createDirectory(destination.deletingLastPathComponent(), true)
      try fileSystemClient.write(data, destination)
    }
  }
}
