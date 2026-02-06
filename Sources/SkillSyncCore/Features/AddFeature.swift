import Dependencies
import Foundation

public struct AddFeature {
  public struct Input: Equatable, Sendable {
    public var sourcePath: String

    public init(sourcePath: String) {
      self.sourcePath = sourcePath
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
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient
  @Dependency(\.date.now) var now

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let sourceRoot = pathClient.resolvePath(input.sourcePath)
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
    let skillRoot = pathClient.skillsyncRoot()
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(skillName, isDirectory: true)
    guard !fileSystemClient.fileExists(skillRoot.path) else {
      throw Error.skillAlreadyExists(skillName)
    }

    try copyDirectory(from: sourceRoot, to: skillRoot)

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

  private func copyDirectory(from source: URL, to destination: URL) throws {
    try fileSystemClient.createDirectory(destination, true)
    let children = try fileSystemClient.contentsOfDirectory(source)
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    for child in children {
      let target = destination.appendingPathComponent(child.lastPathComponent, isDirectory: fileSystemClient.isDirectory(child.path))
      if fileSystemClient.isDirectory(child.path) {
        try copyDirectory(from: child, to: target)
      } else {
        try fileSystemClient.createDirectory(target.deletingLastPathComponent(), true)
        try fileSystemClient.write(try fileSystemClient.data(child), target)
      }
    }
  }

  private static func defaultImportedMeta(createdAt: String, contentHash: String) -> String {
    """
    [skill]
    created = "\(createdAt)"
    source = "imported"
    version = 1
    content-hash = "\(contentHash)"
    state = "active"

    [stats]
    total-invocations = 0
    positive = 0
    negative = 0
    """
  }

  private static func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
  }
}
