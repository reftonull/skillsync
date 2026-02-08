import Dependencies
import Foundation

public struct InfoFeature {
  public struct Input: Equatable, Sendable {
    public var name: String

    public init(name: String) {
      self.name = name
    }
  }

  public struct Result: Equatable, Sendable, Encodable {
    public var name: String
    public var version: Int
    public var state: String
    public var contentHash: String?
    public var created: String?
    public var source: String?
    public var totalInvocations: Int
    public var positive: Int
    public var negative: Int

    public init(
      name: String,
      version: Int,
      state: String,
      contentHash: String?,
      created: String?,
      source: String?,
      totalInvocations: Int,
      positive: Int,
      negative: Int
    ) {
      self.name = name
      self.version = version
      self.state = state
      self.contentHash = contentHash
      self.created = created
      self.source = source
      self.totalInvocations = totalInvocations
      self.positive = positive
      self.negative = negative
    }

    public func formattedOutput() -> String {
      """
      \(name)
        version: \(version)
        state: \(state)
        content-hash: \(contentHash ?? "unknown")
        created: \(created ?? "unknown")
        source: \(source ?? "unknown")
        invocations: \(totalInvocations) (positive: \(positive), negative: \(negative))
      """
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case skillNotFound(String)

    public var description: String {
      switch self {
      case let .skillNotFound(name):
        return "Skill '\(name)' not found."
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

    let meta = try UpdateMetaFeature().read(
      metaURL: skillRoot.appendingPathComponent(".meta.toml")
    )

    let positive = meta.int(section: "stats", key: "positive") ?? 0
    let negative = meta.int(section: "stats", key: "negative") ?? 0
    let total = meta.int(section: "stats", key: "total-invocations") ?? (positive + negative)

    return .init(
      name: input.name,
      version: meta.int(section: "skill", key: "version") ?? 0,
      state: meta.string(section: "skill", key: "state") ?? "active",
      contentHash: meta.string(section: "skill", key: "content-hash"),
      created: meta.string(section: "skill", key: "created"),
      source: meta.string(section: "skill", key: "source"),
      totalInvocations: total,
      positive: positive,
      negative: negative
    )
  }
}
