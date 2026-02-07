import Dependencies
import Foundation

public struct ExportFeature {
  public struct Input: Equatable, Sendable {
    public var name: String
    public var destinationPath: String

    public init(name: String, destinationPath: String) {
      self.name = name
      self.destinationPath = destinationPath
    }
  }

  public struct Result: Equatable, Sendable {
    public var skillName: String
    public var destination: URL

    public init(skillName: String, destination: URL) {
      self.skillName = skillName
      self.destination = destination
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case skillNotFound(String)
    case destinationAlreadyExists(String)

    public var description: String {
      switch self {
      case let .skillNotFound(name):
        return "Skill '\(name)' not found."
      case let .destinationAlreadyExists(path):
        return "Destination already exists: \(path)"
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let source = pathClient.skillsyncRoot()
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(input.name, isDirectory: true)
    guard fileSystemClient.fileExists(source.path), fileSystemClient.isDirectory(source.path) else {
      throw Error.skillNotFound(input.name)
    }

    let destination = pathClient.resolvePath(input.destinationPath)
    guard !fileSystemClient.fileExists(destination.path) else {
      throw Error.destinationAlreadyExists(destination.path)
    }

    try CopyDirectoryFeature().run(
      from: source,
      to: destination,
      excluding: [".meta.toml"]
    )

    return Result(skillName: input.name, destination: destination)
  }
}
