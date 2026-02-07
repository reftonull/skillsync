import Dependencies
import Foundation

public struct EditFeature {
  public struct Input: Equatable, Sendable {
    public var name: String
    public var force: Bool

    public init(name: String, force: Bool) {
      self.name = name
      self.force = force
    }
  }

  public struct Result: Equatable, Sendable {
    public var name: String
    public var editRoot: URL
    public var lockFile: URL

    public init(name: String, editRoot: URL, lockFile: URL) {
      self.name = name
      self.editRoot = editRoot
      self.lockFile = lockFile
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case skillNotFound(String)
    case lockAlreadyHeld(name: String, lockFile: String)

    public var description: String {
      switch self {
      case let .skillNotFound(name):
        return "Skill '\(name)' not found."
      case let .lockAlreadyHeld(name, lockFile):
        return "Skill '\(name)' is already being edited. Lock file: \(lockFile)"
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient
  @Dependency(\.date.now) var now

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let storeRoot = pathClient.skillsyncRoot()
    let skillsRoot = storeRoot.appendingPathComponent("skills", isDirectory: true)
    let canonicalSkillRoot = skillsRoot.appendingPathComponent(input.name, isDirectory: true)
    guard fileSystemClient.fileExists(canonicalSkillRoot.path), fileSystemClient.isDirectory(canonicalSkillRoot.path)
    else {
      throw Error.skillNotFound(input.name)
    }

    let editingRoot = storeRoot.appendingPathComponent("editing", isDirectory: true)
    let skillEditRoot = editingRoot.appendingPathComponent(input.name, isDirectory: true)
    let locksRoot = storeRoot.appendingPathComponent("locks", isDirectory: true)
    let lockFile = locksRoot.appendingPathComponent("\(input.name).lock")

    if fileSystemClient.fileExists(lockFile.path) {
      guard input.force else {
        throw Error.lockAlreadyHeld(name: input.name, lockFile: lockFile.path)
      }
      try fileSystemClient.removeItem(lockFile)
    }

    try fileSystemClient.createDirectory(editingRoot, true)
    if input.force, fileSystemClient.fileExists(skillEditRoot.path) {
      try fileSystemClient.removeItem(skillEditRoot)
    }
    if !fileSystemClient.fileExists(skillEditRoot.path) {
      try CopyDirectoryFeature().run(
        from: canonicalSkillRoot,
        to: skillEditRoot,
        excluding: [".meta.toml"]
      )
    }

    try fileSystemClient.createDirectory(locksRoot, true)
    try fileSystemClient.write(
      Data(Self.lockContents(now: now, currentDirectory: pathClient.currentDirectory()).utf8),
      lockFile
    )

    return Result(
      name: input.name,
      editRoot: skillEditRoot,
      lockFile: lockFile
    )
  }

  private static func lockContents(now: Date, currentDirectory: URL) -> String {
    """
    acquired = "\(Self.formatDate(now))"
    cwd = "\(currentDirectory.path)"
    """
  }

  private static func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
  }
}
