import Dependencies
import Foundation

public struct AbortFeature {
  public struct Input: Equatable, Sendable {
    public var name: String

    public init(name: String) {
      self.name = name
    }
  }

  public struct Result: Equatable, Sendable {
    public var name: String
    public var removedEditCopy: Bool

    public init(name: String, removedEditCopy: Bool) {
      self.name = name
      self.removedEditCopy = removedEditCopy
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case lockNotHeld(name: String, lockFile: String)

    public var description: String {
      switch self {
      case let .lockNotHeld(name, lockFile):
        return "No active edit lock for '\(name)'. Lock file: \(lockFile)"
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let storeRoot = pathClient.skillsyncRoot()
    let editRoot = storeRoot
      .appendingPathComponent("editing", isDirectory: true)
      .appendingPathComponent(input.name, isDirectory: true)
    let lockFile = storeRoot
      .appendingPathComponent("locks", isDirectory: true)
      .appendingPathComponent("\(input.name).lock")

    guard fileSystemClient.fileExists(lockFile.path) else {
      throw Error.lockNotHeld(name: input.name, lockFile: lockFile.path)
    }

    let removedEditCopy = fileSystemClient.fileExists(editRoot.path)
    if removedEditCopy {
      try fileSystemClient.removeItem(editRoot)
    }
    try fileSystemClient.removeItem(lockFile)

    return Result(name: input.name, removedEditCopy: removedEditCopy)
  }
}
