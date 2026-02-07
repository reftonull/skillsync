import Dependencies
import Foundation

public struct InitFeature {
  public struct Result: Equatable, Sendable {
    public var storeRoot: URL
    public var createdConfig: Bool

    public init(storeRoot: URL, createdConfig: Bool) {
      self.storeRoot = storeRoot
      self.createdConfig = createdConfig
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run() throws -> Result {
    let storeRoot = pathClient.skillsyncRoot()
    let skills = storeRoot.appendingPathComponent("skills", isDirectory: true)
    let editing = storeRoot.appendingPathComponent("editing", isDirectory: true)
    let locks = storeRoot.appendingPathComponent("locks", isDirectory: true)
    let rendered = storeRoot.appendingPathComponent("rendered", isDirectory: true)
    let logs = storeRoot.appendingPathComponent("logs", isDirectory: true)
    let config = storeRoot.appendingPathComponent("config.toml")

    try fileSystemClient.createDirectory(storeRoot, true)
    try fileSystemClient.createDirectory(skills, true)
    try fileSystemClient.createDirectory(editing, true)
    try fileSystemClient.createDirectory(locks, true)
    try fileSystemClient.createDirectory(rendered, true)
    try fileSystemClient.createDirectory(logs, true)

    let createdConfig = !fileSystemClient.fileExists(config.path)
    if createdConfig {
      try fileSystemClient.write(Data(Self.defaultConfig.utf8), config)
    }

    return Result(storeRoot: storeRoot, createdConfig: createdConfig)
  }

  static let defaultConfig = """
    [skillsync]
    version = "1"

    [observation]
    mode = "on"
    """
}
