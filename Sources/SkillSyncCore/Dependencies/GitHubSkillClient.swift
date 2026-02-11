import Dependencies
import Foundation

public struct GitHubSkillClient: Sendable {
  public struct FetchResult: Equatable, Sendable {
    public var files: [String: Data]
    public var resolvedRef: String
    public var commit: String

    public init(files: [String: Data], resolvedRef: String, commit: String) {
      self.files = files
      self.resolvedRef = resolvedRef
      self.commit = commit
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case skillPathNotFound(String)
    case symbolicLinkNotAllowed(String)
    case gitCommandFailed(command: String, details: String)

    public var description: String {
      switch self {
      case let .skillPathNotFound(path):
        return "Skill path not found in repository: \(path)"
      case let .symbolicLinkNotAllowed(path):
        return "Symbolic links are not allowed in GitHub skill payload: \(path)"
      case let .gitCommandFailed(command, details):
        if details.isEmpty {
          return "Git command failed: \(command)"
        }
        return "Git command failed: \(command)\n\(details)"
      }
    }
  }

  public var fetch: @Sendable (GitHubSkillSource) throws -> FetchResult

  public init(fetch: @escaping @Sendable (GitHubSkillSource) throws -> FetchResult) {
    self.fetch = fetch
  }

  public static let live = GitHubSkillClient { source in
    @Dependency(\.gitClient) var gitClient
    @Dependency(\.fileSystemClient) var fileSystemClient

    let tempRoot = URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
      .appendingPathComponent("skillsync-github-\(UUID().uuidString)", isDirectory: true)
    try fileSystemClient.createDirectory(tempRoot, true)
    defer {
      try? fileSystemClient.removeItem(tempRoot)
    }

    let checkoutRoot = tempRoot.appendingPathComponent("checkout", isDirectory: true)
    try fileSystemClient.createDirectory(checkoutRoot, true)

    let repoURL = "https://github.com/\(source.repo).git"
    try gitClient.runRequired(checkoutRoot, ["init"]) { command, details in
      Error.gitCommandFailed(command: command, details: details)
    }
    try gitClient.runRequired(checkoutRoot, ["remote", "add", "origin", repoURL]) { command, details in
      Error.gitCommandFailed(command: command, details: details)
    }
    try gitClient.runRequired(checkoutRoot, ["sparse-checkout", "init", "--cone"]) { command, details in
      Error.gitCommandFailed(command: command, details: details)
    }
    try gitClient.runRequired(checkoutRoot, ["sparse-checkout", "set", source.skillPath]) { command, details in
      Error.gitCommandFailed(command: command, details: details)
    }
    try gitClient.runRequired(checkoutRoot, ["fetch", "--depth", "1", "origin", source.ref]) { command, details in
      Error.gitCommandFailed(command: command, details: details)
    }
    try gitClient.runRequired(checkoutRoot, ["checkout", "FETCH_HEAD"]) { command, details in
      Error.gitCommandFailed(command: command, details: details)
    }

    let commit = try gitClient.runRequired(checkoutRoot, ["rev-parse", "HEAD"]) { command, details in
      Error.gitCommandFailed(command: command, details: details)
    }
    .stdout
    .trimmingCharacters(in: .whitespacesAndNewlines)

    let skillRoot = checkoutRoot.appendingPathComponent(source.skillPath, isDirectory: true)
    guard fileSystemClient.fileExists(skillRoot.path), fileSystemClient.isDirectory(skillRoot.path) else {
      throw Error.skillPathNotFound(source.skillPath)
    }

    let files = try collectFiles(in: skillRoot, fileSystemClient: fileSystemClient)
    return FetchResult(files: files, resolvedRef: source.ref, commit: commit)
  }
}

private func collectFiles(
  in directory: URL,
  fileSystemClient: FileSystemClient
) throws -> [String: Data] {
  var files: [String: Data] = [:]
  try collectFilesRecursive(
    current: directory,
    root: directory,
    fileSystemClient: fileSystemClient,
    files: &files
  )
  return files
}

private func collectFilesRecursive(
  current: URL,
  root: URL,
  fileSystemClient: FileSystemClient,
  files: inout [String: Data]
) throws {
  for child in try fileSystemClient.contentsOfDirectory(current).sorted(by: { $0.path < $1.path }) {
    if fileSystemClient.isSymbolicLink(child.path) {
      let relativePath = relativePath(from: child, base: root)
      throw GitHubSkillClient.Error.symbolicLinkNotAllowed(relativePath)
    }
    if fileSystemClient.isDirectory(child.path) {
      try collectFilesRecursive(
        current: child,
        root: root,
        fileSystemClient: fileSystemClient,
        files: &files
      )
    } else {
      let relativePath = relativePath(from: child, base: root)
      files[relativePath] = try fileSystemClient.data(child)
    }
  }
}

private func relativePath(from file: URL, base: URL) -> String {
  let filePath = file.standardizedFileURL.path
  let basePath = base.standardizedFileURL.path
  if filePath.hasPrefix(basePath + "/") {
    return String(filePath.dropFirst(basePath.count + 1))
  }
  return file.lastPathComponent
}

private enum GitHubSkillClientKey: DependencyKey {
  static var liveValue: GitHubSkillClient {
    .live
  }

  static var testValue: GitHubSkillClient {
    GitHubSkillClient { _ in
      fatalError(
        """
        Unimplemented GitHubSkillClient.fetch.
        Override `githubSkillClient` in this test using `.dependencies { ... }`.
        """
      )
    }
  }
}

public extension DependencyValues {
  var githubSkillClient: GitHubSkillClient {
    get { self[GitHubSkillClientKey.self] }
    set { self[GitHubSkillClientKey.self] = newValue }
  }
}
