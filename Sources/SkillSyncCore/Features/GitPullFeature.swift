import Dependencies
import Foundation

public struct GitPullFeature {
  public struct Result: Equatable, Sendable {
    public var storeRoot: URL
    public var syncResult: SyncRenderFeature.Result?

    public init(storeRoot: URL, syncResult: SyncRenderFeature.Result?) {
      self.storeRoot = storeRoot
      self.syncResult = syncResult
    }

    public var skippedSync: Bool {
      syncResult == nil
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case storeNotInitialized(String)
    case notGitRepository(String)
    case gitCommandFailed(command: String, details: String)

    public var description: String {
      switch self {
      case let .storeNotInitialized(path):
        return "skillsync store not found at \(path). Run `skillsync init` first."
      case let .notGitRepository(path):
        return "No git repository found at \(path). Run `skillsync remote set <url>` first."
      case let .gitCommandFailed(command, details):
        if details.isEmpty {
          return "Git command failed: \(command)"
        }
        return "Git command failed: \(command)\n\(details)"
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient
  @Dependency(\.gitClient) var gitClient

  public init() {}

  public func run() throws -> Result {
    let storeRoot = pathClient.skillsyncRoot().standardizedFileURL
    guard fileSystemClient.fileExists(storeRoot.path), fileSystemClient.isDirectory(storeRoot.path) else {
      throw Error.storeNotInitialized(storeRoot.path)
    }

    let gitDirectory = storeRoot.appendingPathComponent(".git", isDirectory: true)
    guard fileSystemClient.fileExists(gitDirectory.path), fileSystemClient.isDirectory(gitDirectory.path) else {
      throw Error.notGitRepository(storeRoot.path)
    }

    try gitClient.runRequired(storeRoot, ["pull", "--ff-only"]) { command, details in
      Error.gitCommandFailed(command: command, details: details)
    }

    let config = try LoadSyncConfigFeature().run()
    guard !config.targets.isEmpty else {
      return Result(storeRoot: storeRoot, syncResult: nil)
    }

    let syncResult = try SyncRenderFeature().run(
      .init(targets: config.targets, observation: config.observation)
    )

    return Result(storeRoot: storeRoot, syncResult: syncResult)
  }
}
