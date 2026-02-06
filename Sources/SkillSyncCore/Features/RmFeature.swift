import Dependencies
import Foundation

public struct RmFeature {
  public struct Input: Equatable, Sendable {
    public var name: String

    public init(name: String) {
      self.name = name
    }
  }

  public struct Result: Equatable, Sendable {
    public var skillName: String

    public init(skillName: String) {
      self.skillName = skillName
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case skillNotFound(String)
    case metaNotFound(String)

    public var description: String {
      switch self {
      case let .skillNotFound(name):
        return "Skill '\(name)' not found."
      case let .metaNotFound(name):
        return "Skill '\(name)' is missing .meta.toml."
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let skillRoot = pathClient.skillsyncRoot()
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(input.name, isDirectory: true)
    guard fileSystemClient.fileExists(skillRoot.path), fileSystemClient.isDirectory(skillRoot.path) else {
      throw Error.skillNotFound(input.name)
    }

    let metaURL = skillRoot.appendingPathComponent(".meta.toml")
    guard fileSystemClient.fileExists(metaURL.path), !fileSystemClient.isDirectory(metaURL.path) else {
      throw Error.metaNotFound(input.name)
    }

    try UpdateMetaFeature().run(
      metaURL: metaURL,
      updates: [
        .init(
          section: "skill",
          key: "state",
          operation: .setString("pending_remove")
        )
      ]
    )

    return Result(skillName: input.name)
  }
}
