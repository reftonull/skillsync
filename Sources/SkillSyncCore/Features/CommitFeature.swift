import Dependencies
import Foundation

public struct CommitFeature {
  public struct Input: Equatable, Sendable {
    public var name: String
    public var reason: String

    public init(name: String, reason: String) {
      self.name = name
      self.reason = reason
    }
  }

  public struct Result: Equatable, Sendable {
    public var name: String
    public var contentHash: String
    public var versionAfter: Int

    public init(name: String, contentHash: String, versionAfter: Int) {
      self.name = name
      self.contentHash = contentHash
      self.versionAfter = versionAfter
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case skillNotFound(String)
    case editCopyNotFound(String)
    case lockNotHeld(name: String, lockFile: String)
    case reservedPath(String)

    public var description: String {
      switch self {
      case let .skillNotFound(name):
        return "Skill '\(name)' not found."
      case let .editCopyNotFound(name):
        return "No active edit copy for skill '\(name)'. Run `skillsync edit \(name)` first."
      case let .lockNotHeld(name, lockFile):
        return "No active edit lock for '\(name)'. Lock file: \(lockFile)"
      case let .reservedPath(path):
        return "Path '\(path)' is reserved and cannot be committed."
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let _ = input.reason

    let storeRoot = pathClient.skillsyncRoot()
    let canonicalRoot = storeRoot
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(input.name, isDirectory: true)
    let editRoot = storeRoot
      .appendingPathComponent("editing", isDirectory: true)
      .appendingPathComponent(input.name, isDirectory: true)
    let lockFile = storeRoot
      .appendingPathComponent("locks", isDirectory: true)
      .appendingPathComponent("\(input.name).lock")

    guard fileSystemClient.fileExists(lockFile.path) else {
      throw Error.lockNotHeld(name: input.name, lockFile: lockFile.path)
    }
    guard fileSystemClient.fileExists(canonicalRoot.path), fileSystemClient.isDirectory(canonicalRoot.path) else {
      throw Error.skillNotFound(input.name)
    }
    guard fileSystemClient.fileExists(editRoot.path), fileSystemClient.isDirectory(editRoot.path) else {
      throw Error.editCopyNotFound(input.name)
    }

    let reservedMeta = editRoot.appendingPathComponent(".meta.toml")
    if fileSystemClient.fileExists(reservedMeta.path) {
      throw Error.reservedPath(".meta.toml")
    }

    try removeCanonicalChildren(exceptingMetaIn: canonicalRoot)
    try CopyDirectoryFeature().run(
      from: editRoot,
      to: canonicalRoot,
      excluding: [".meta.toml"]
    )

    let contentHash = try SkillContentHashFeature().run(skillDirectory: canonicalRoot)
    let metaURL = canonicalRoot.appendingPathComponent(".meta.toml")
    try UpdateMetaFeature().run(
      metaURL: metaURL,
      updates: [
        .init(section: "skill", key: "content-hash", operation: .setString(contentHash)),
        .init(section: "skill", key: "version", operation: .incrementInt(1)),
      ]
    )

    let meta = try UpdateMetaFeature().read(metaURL: metaURL)
    let version = meta.int(section: "skill", key: "version") ?? 0

    try fileSystemClient.removeItem(editRoot)
    try fileSystemClient.removeItem(lockFile)

    return Result(name: input.name, contentHash: contentHash, versionAfter: version)
  }

  private func removeCanonicalChildren(exceptingMetaIn skillRoot: URL) throws {
    for child in try fileSystemClient.contentsOfDirectory(skillRoot) {
      if child.lastPathComponent == ".meta.toml" {
        continue
      }
      try fileSystemClient.removeItem(child)
    }
  }
}
