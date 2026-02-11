import Foundation

public struct GitHubSkillSource: Equatable, Sendable {
  public var repo: String
  public var skillPath: String
  public var ref: String

  public init(repo: String, skillPath: String, ref: String = "main") throws {
    let normalizedRepo = try Self.normalizeRepo(repo)
    let normalizedPath = try Self.normalizeSkillPath(skillPath)
    let normalizedRef = Self.normalizeRef(ref)

    guard !normalizedRef.isEmpty else {
      throw ParseError.invalidRef(ref)
    }

    self.repo = normalizedRepo
    self.skillPath = normalizedPath
    self.ref = normalizedRef
  }

  public enum ParseError: Swift.Error, Equatable, CustomStringConvertible {
    case invalidRepo(String)
    case invalidSkillPath(String)
    case invalidRef(String)
    case invalidURL(String)

    public var description: String {
      switch self {
      case let .invalidRepo(repo):
        return "Invalid GitHub repo '\(repo)'. Expected <owner>/<repo>."
      case let .invalidSkillPath(path):
        return "Invalid skill path '\(path)'."
      case let .invalidRef(ref):
        return "Invalid ref '\(ref)'."
      case let .invalidURL(url):
        return "Invalid GitHub URL '\(url)'. Expected https://github.com/<owner>/<repo>/tree/<ref>/<path>."
      }
    }
  }

  public static func parse(urlString: String) throws -> Self {
    guard let url = URL(string: urlString), let host = url.host?.lowercased(), host == "github.com" else {
      throw ParseError.invalidURL(urlString)
    }

    let components = url.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    guard components.count >= 5 else {
      throw ParseError.invalidURL(urlString)
    }
    guard components[2] == "tree" else {
      throw ParseError.invalidURL(urlString)
    }

    let repo = "\(components[0])/\(components[1])"
    let ref = components[3]
    let path = components.dropFirst(4).joined(separator: "/")
    return try .init(repo: repo, skillPath: path, ref: ref)
  }

  private static func normalizeRepo(_ value: String) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    let pattern = #"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"#
    guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
      throw ParseError.invalidRepo(value)
    }
    return trimmed
  }

  private static func normalizeSkillPath(_ value: String) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let sanitized = SkillRelativePath.sanitize(trimmed) else {
      throw ParseError.invalidSkillPath(value)
    }
    return sanitized
  }

  private static func normalizeRef(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
