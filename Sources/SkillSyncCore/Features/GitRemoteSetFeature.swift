import Dependencies
import Foundation

public struct GitRemoteSetFeature {
  public struct Input: Equatable, Sendable {
    public var remoteName: String
    public var remoteURL: String

    public init(remoteName: String, remoteURL: String) {
      self.remoteName = remoteName
      self.remoteURL = remoteURL
    }
  }

  public enum Action: String, Equatable, Sendable {
    case added
    case updated
  }

  public struct Result: Equatable, Sendable {
    public var storeRoot: URL
    public var remoteName: String
    public var remoteURL: String
    public var initializedRepository: Bool
    public var action: Action

    public init(
      storeRoot: URL,
      remoteName: String,
      remoteURL: String,
      initializedRepository: Bool,
      action: Action
    ) {
      self.storeRoot = storeRoot
      self.remoteName = remoteName
      self.remoteURL = remoteURL
      self.initializedRepository = initializedRepository
      self.action = action
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case invalidRemoteName
    case gitCommandFailed(command: String, details: String)

    public var description: String {
      switch self {
      case .invalidRemoteName:
        return "Remote name must not be empty."
      case let .gitCommandFailed(command, details):
        if details.isEmpty {
          return "Git command failed: \(command)"
        }
        return "Git command failed: \(command)\n\(details)"
      }
    }
  }

  @Dependency(\.fileSystemClient) var fileSystemClient
  @Dependency(\.gitClient) var gitClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let remoteName = input.remoteName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !remoteName.isEmpty else {
      throw Error.invalidRemoteName
    }

    let initResult = try InitFeature().run()
    let storeRoot = initResult.storeRoot

    var initializedRepository = false
    let gitDirectory = storeRoot.appendingPathComponent(".git", isDirectory: true)
    if !fileSystemClient.fileExists(gitDirectory.path) {
      try gitClient.runRequired(storeRoot, ["init"]) { command, details in
        Error.gitCommandFailed(command: command, details: details)
      }
      initializedRepository = true
    }

    let getURLResult = try gitClient.run(storeRoot, ["remote", "get-url", remoteName])
    let action: Action
    if getURLResult.succeeded {
      try gitClient.runRequired(storeRoot, ["remote", "set-url", remoteName, input.remoteURL]) {
        command, details in
        Error.gitCommandFailed(command: command, details: details)
      }
      action = .updated
    } else {
      try gitClient.runRequired(storeRoot, ["remote", "add", remoteName, input.remoteURL]) {
        command, details in
        Error.gitCommandFailed(command: command, details: details)
      }
      action = .added
    }

    return Result(
      storeRoot: storeRoot,
      remoteName: remoteName,
      remoteURL: input.remoteURL,
      initializedRepository: initializedRepository,
      action: action
    )
  }
}
