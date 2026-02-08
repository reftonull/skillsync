import Dependencies
import Foundation

public struct GitPushFeature {
  public struct Input: Equatable, Sendable {
    public var remoteName: String
    public var message: String?

    public init(remoteName: String, message: String?) {
      self.remoteName = remoteName
      self.message = message
    }
  }

  public struct Result: Equatable, Sendable {
    public var storeRoot: URL
    public var remoteName: String
    public var committed: Bool
    public var commitMessage: String?

    public init(
      storeRoot: URL,
      remoteName: String,
      committed: Bool,
      commitMessage: String?
    ) {
      self.storeRoot = storeRoot
      self.remoteName = remoteName
      self.committed = committed
      self.commitMessage = commitMessage
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case storeNotInitialized(String)
    case notGitRepository(String)
    case invalidRemoteName
    case gitCommandFailed(command: String, details: String)

    public var description: String {
      switch self {
      case let .storeNotInitialized(path):
        return "skillsync store not found at \(path). Run `skillsync init` first."
      case let .notGitRepository(path):
        return "No git repository found at \(path). Run `skillsync remote set <url>` first."
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

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient
  @Dependency(\.gitClient) var gitClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let remoteName = input.remoteName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !remoteName.isEmpty else {
      throw Error.invalidRemoteName
    }

    let storeRoot = pathClient.skillsyncRoot().standardizedFileURL
    guard fileSystemClient.fileExists(storeRoot.path), fileSystemClient.isDirectory(storeRoot.path) else {
      throw Error.storeNotInitialized(storeRoot.path)
    }

    let gitDirectory = storeRoot.appendingPathComponent(".git", isDirectory: true)
    guard fileSystemClient.fileExists(gitDirectory.path), fileSystemClient.isDirectory(gitDirectory.path) else {
      throw Error.notGitRepository(storeRoot.path)
    }

    try gitClient.runRequired(storeRoot, ["add", "-A"]) { command, details in
      Error.gitCommandFailed(command: command, details: details)
    }

    let stagedDiff = try gitClient.run(storeRoot, ["diff", "--cached", "--quiet"])
    let committed: Bool
    let commitMessage: String?
    switch stagedDiff.exitCode {
    case 0:
      committed = false
      commitMessage = nil
    case 1:
      let message = normalizedCommitMessage(input.message)
      try gitClient.runRequired(storeRoot, ["commit", "-m", message]) { command, details in
        Error.gitCommandFailed(command: command, details: details)
      }
      committed = true
      commitMessage = message
    default:
      throw Error.gitCommandFailed(
        command: GitClient.commandString(["diff", "--cached", "--quiet"]),
        details: GitClient.commandDetails(stdout: stagedDiff.stdout, stderr: stagedDiff.stderr)
      )
    }

    try gitClient.runRequired(storeRoot, ["push", "--set-upstream", remoteName, "HEAD"]) {
      command, details in
      Error.gitCommandFailed(command: command, details: details)
    }

    return Result(
      storeRoot: storeRoot,
      remoteName: remoteName,
      committed: committed,
      commitMessage: commitMessage
    )
  }

  private func normalizedCommitMessage(_ rawMessage: String?) -> String {
    let message = rawMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let message, !message.isEmpty {
      return message
    }
    return "skillsync: update skills"
  }
}
