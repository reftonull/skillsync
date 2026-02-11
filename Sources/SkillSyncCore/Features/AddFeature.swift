import Dependencies
import Foundation

public struct AddFeature {
  public struct Input: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
      case localPath(String)
      case github(GitHubSkillSource)
    }

    public var source: Source

    public init(source: Source) {
      self.source = source
    }

    public init(sourcePath: String) {
      self.source = .localPath(sourcePath)
    }

    public init(githubSource: GitHubSkillSource) {
      self.source = .github(githubSource)
    }
  }

  public struct Result: Equatable, Sendable {
    public var skillName: String
    public var skillRoot: URL
    public var createdMeta: Bool
    public var contentHash: String

    public init(
      skillName: String,
      skillRoot: URL,
      createdMeta: Bool,
      contentHash: String
    ) {
      self.skillName = skillName
      self.skillRoot = skillRoot
      self.createdMeta = createdMeta
      self.contentHash = contentHash
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case sourcePathNotFound(String)
    case sourcePathNotDirectory(String)
    case missingSkillMarkdown(String)
    case skillAlreadyExists(String)
    case invalidGitHubSkillPath(String)

    public var description: String {
      switch self {
      case let .sourcePathNotFound(path):
        return "Source path not found: \(path)"
      case let .sourcePathNotDirectory(path):
        return "Source path is not a directory: \(path)"
      case let .missingSkillMarkdown(path):
        return "Skill directory '\(path)' must contain SKILL.md."
      case let .skillAlreadyExists(name):
        return "Skill '\(name)' already exists."
      case let .invalidGitHubSkillPath(path):
        return "Invalid file path in GitHub skill payload: \(path)"
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient
  @Dependency(\.githubSkillClient) var githubSkillClient
  @Dependency(\.date.now) var now

  public init() {}

  public func run(_ input: Input) throws -> Result {
    switch input.source {
    case let .localPath(sourcePath):
      return try self.runLocalImport(sourcePath: sourcePath)
    case let .github(source):
      return try self.runGitHubImport(source: source)
    }
  }

  private func runLocalImport(sourcePath: String) throws -> Result {
    let sourceRoot = pathClient.resolvePath(sourcePath)
    guard fileSystemClient.fileExists(sourceRoot.path) else {
      throw Error.sourcePathNotFound(sourceRoot.path)
    }
    guard fileSystemClient.isDirectory(sourceRoot.path) else {
      throw Error.sourcePathNotDirectory(sourceRoot.path)
    }
    let skillMarkdown = sourceRoot.appendingPathComponent("SKILL.md")
    guard fileSystemClient.fileExists(skillMarkdown.path), !fileSystemClient.isDirectory(skillMarkdown.path) else {
      throw Error.missingSkillMarkdown(sourceRoot.path)
    }

    let skillName = sourceRoot.lastPathComponent
    let skillRoot = try self.destinationRoot(for: skillName)

    try CopyDirectoryFeature().run(from: sourceRoot, to: skillRoot)

    let contentHash = try SkillContentHashFeature().run(skillDirectory: skillRoot)
    let metaURL = skillRoot.appendingPathComponent(".meta.toml")
    let createdMeta: Bool
    if fileSystemClient.fileExists(metaURL.path) {
      createdMeta = false
      try UpdateMetaFeature().run(
        metaURL: metaURL,
        updates: [
          .init(
            section: "skill",
            key: "content-hash",
            operation: .setString(contentHash)
          )
        ]
      )
    } else {
      createdMeta = true
      let createdAt = Self.formatDate(now)
      let meta = Self.defaultImportedMeta(createdAt: createdAt, contentHash: contentHash)
      try fileSystemClient.write(Data(meta.utf8), metaURL)
    }

    return Result(
      skillName: skillName,
      skillRoot: skillRoot,
      createdMeta: createdMeta,
      contentHash: contentHash
    )
  }

  private func runGitHubImport(source: GitHubSkillSource) throws -> Result {
    let fetched = try githubSkillClient.fetch(source)
    guard fetched.files["SKILL.md"] != nil else {
      throw Error.missingSkillMarkdown(source.skillPath)
    }

    let skillName = URL(filePath: source.skillPath, directoryHint: .isDirectory).lastPathComponent
    let skillRoot = try self.destinationRoot(for: skillName)
    try fileSystemClient.createDirectory(skillRoot, true)

    for key in fetched.files.keys.sorted() {
      guard let sanitized = SkillRelativePath.sanitize(key) else {
        throw Error.invalidGitHubSkillPath(key)
      }
      if sanitized == ".meta.toml" {
        continue
      }
      guard let data = fetched.files[key] else { continue }
      let destination = skillRoot.appendingPathComponent(sanitized)
      try fileSystemClient.createDirectory(destination.deletingLastPathComponent(), true)
      try fileSystemClient.write(data, destination)
    }

    let contentHash = try SkillContentHashFeature().run(skillDirectory: skillRoot)
    let createdAt = Self.formatDate(now)
    let meta = Self.defaultGitHubMeta(
      createdAt: createdAt,
      contentHash: contentHash,
      repo: source.repo,
      skillPath: source.skillPath,
      ref: fetched.resolvedRef,
      commit: fetched.commit
    )
    try fileSystemClient.write(Data(meta.utf8), skillRoot.appendingPathComponent(".meta.toml"))

    return Result(
      skillName: skillName,
      skillRoot: skillRoot,
      createdMeta: true,
      contentHash: contentHash
    )
  }

  private func destinationRoot(for skillName: String) throws -> URL {
    let skillRoot = pathClient.skillsyncRoot()
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(skillName, isDirectory: true)
    guard !fileSystemClient.fileExists(skillRoot.path) else {
      throw Error.skillAlreadyExists(skillName)
    }
    return skillRoot
  }

  private static func defaultImportedMeta(createdAt: String, contentHash: String) -> String {
    """
    [skill]
    created = "\(createdAt)"
    source = "imported"
    version = 1
    content-hash = "\(contentHash)"
    state = "active"
    """
  }

  private static func defaultGitHubMeta(
    createdAt: String,
    contentHash: String,
    repo: String,
    skillPath: String,
    ref: String,
    commit: String
  ) -> String {
    """
    [skill]
    created = "\(createdAt)"
    source = "github"
    version = 1
    content-hash = "\(contentHash)"
    state = "active"

    [upstream]
    repo = "\(escaped(repo))"
    skill-path = "\(escaped(skillPath))"
    ref = "\(escaped(ref))"
    commit = "\(escaped(commit))"
    base-content-hash = "\(contentHash)"
    """
  }

  // These values are expected to be single-line Git metadata, but we still
  // escape common control characters to keep generated TOML valid.
  private static func escaped(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\t", with: "\\t")
  }

  private static func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
  }
}
