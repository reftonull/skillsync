import Dependencies
import Foundation

public struct NewFeature {
  public struct Input: Equatable, Sendable {
    public var name: String
    public var description: String?

    public init(name: String, description: String?) {
      self.name = name
      self.description = description
    }
  }

  public struct Result: Equatable, Sendable {
    public var skillRoot: URL
    public var contentHash: String

    public init(skillRoot: URL, contentHash: String) {
      self.skillRoot = skillRoot
      self.contentHash = contentHash
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case invalidName(String)
    case skillAlreadyExists(String)

    public var description: String {
      switch self {
      case let .invalidName(name):
        return "Invalid skill name '\(name)'. Use lowercase letters, numbers, '-' or '_'."
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
    guard Self.isValidSkillName(input.name) else {
      throw Error.invalidName(input.name)
    }

    let skillsRoot = pathClient.skillsyncRoot().appendingPathComponent("skills", isDirectory: true)
    let skillRoot = skillsRoot.appendingPathComponent(input.name, isDirectory: true)

    guard !fileSystemClient.fileExists(skillRoot.path) else {
      throw Error.skillAlreadyExists(input.name)
    }

    try fileSystemClient.createDirectory(skillRoot, true)

    let skillMarkdown = Self.skillMarkdown(name: input.name, description: input.description)
    try fileSystemClient.write(Data(skillMarkdown.utf8), skillRoot.appendingPathComponent("SKILL.md"))

    let contentHash = try SkillContentHashFeature().run(skillDirectory: skillRoot)
    let createdAt = Self.formatDate(now)
    let meta = Self.metaToml(createdAt: createdAt, contentHash: contentHash)
    try fileSystemClient.write(Data(meta.utf8), skillRoot.appendingPathComponent(".meta.toml"))

    return Result(skillRoot: skillRoot, contentHash: contentHash)
  }

  static func isValidSkillName(_ name: String) -> Bool {
    let pattern = #"^[a-z0-9][a-z0-9_-]*$"#
    return name.range(of: pattern, options: .regularExpression) != nil
  }

  private static func skillMarkdown(name: String, description: String?) -> String {
    if let description, !description.isEmpty {
      return """
        # \(name)

        \(description)
        """
    }
    return """
      # \(name)

      TODO: Describe this skill.
      """
  }

  private static func metaToml(createdAt: String, contentHash: String) -> String {
    """
    [skill]
    created = "\(createdAt)"
    source = "hand-authored"
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
