import Dependencies
import Foundation

public struct AddFeature {
  public struct Input: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
      case localPath(String)
      case github(GitHubSkillSource)
    }

    public var source: Source

    public init(source: Source) {
      self.source = source
    }

    public init(sourcePath: String) {
      self.source = .localPath(sourcePath)
    }

    public init(githubSource: GitHubSkillSource) {
      self.source = .github(githubSource)
    }
  }

  public struct Result: Equatable, Sendable {
    public var skills: [SkillResult]

    public init(skills: [SkillResult]) {
      self.skills = skills
    }
  }

  public struct SkillResult: Equatable, Sendable {
    public var status: Status
    public var skillName: String

    public init(status: Status, skillName: String) {
      self.status = status
      self.skillName = skillName
    }
  }

  public enum Status: Equatable, Sendable {
    case imported(skillRoot: URL, contentHash: String, createdMeta: Bool)
    case skippedExists
    case skippedInvalid(reason: String)

    public var isImported: Bool {
      if case .imported = self { return true }
      return false
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case sourcePathNotFound(String)
    case sourcePathNotDirectory(String)
    case skillAlreadyExists(String)
    case invalidGitHubSkillPath(String)
    case noSkillsFound(String)

    public var description: String {
      switch self {
      case let .sourcePathNotFound(path):
        return "Source path not found: \(path)"
      case let .sourcePathNotDirectory(path):
        return "Source path is not a directory: \(path)"
      case let .skillAlreadyExists(name):
        return "Skill '\(name)' already exists."
      case let .invalidGitHubSkillPath(path):
        return "Invalid file path in GitHub skill payload: \(path)"
      case let .noSkillsFound(path):
        return "No skill directories found in '\(path)'."
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient
  @Dependency(\.githubSkillClient) var githubSkillClient
  @Dependency(\.date.now) var now

  public init() {}

  public func run(_ input: Input) throws -> Result {
    switch input.source {
    case let .localPath(sourcePath):
      return try self.runLocalImport(sourcePath: sourcePath)
    case let .github(source):
      return try self.runGitHubImport(source: source)
    }
  }

  private func runLocalImport(sourcePath: String) throws -> Result {
    let sourceRoot = pathClient.resolvePath(sourcePath)
    guard fileSystemClient.fileExists(sourceRoot.path) else {
      throw Error.sourcePathNotFound(sourceRoot.path)
    }
    guard fileSystemClient.isDirectory(sourceRoot.path) else {
      throw Error.sourcePathNotDirectory(sourceRoot.path)
    }

    let skillMarkdown = sourceRoot.appendingPathComponent("SKILL.md")
    if fileSystemClient.fileExists(skillMarkdown.path), !fileSystemClient.isDirectory(skillMarkdown.path) {
      return try runLocalSingleImport(sourceRoot: sourceRoot)
    }

    return try runLocalBatchImport(sourceRoot: sourceRoot)
  }

  private func runLocalSingleImport(sourceRoot: URL) throws -> Result {
    let skillName = sourceRoot.lastPathComponent
    let skillRoot = try self.destinationRoot(for: skillName)

    try CopyDirectoryFeature().run(from: sourceRoot, to: skillRoot)

    let contentHash = try SkillContentHashFeature().run(skillDirectory: skillRoot)
    let metaURL = skillRoot.appendingPathComponent(".meta.toml")
    let createdMeta: Bool
    if fileSystemClient.fileExists(metaURL.path) {
      createdMeta = false
      try UpdateMetaFeature().run(
        metaURL: metaURL,
        updates: [
          .init(
            section: "skill",
            key: "content-hash",
            operation: .setString(contentHash)
          )
        ]
      )
    } else {
      createdMeta = true
      let createdAt = Self.formatDate(now)
      let meta = Self.defaultImportedMeta(createdAt: createdAt, contentHash: contentHash)
      try fileSystemClient.write(Data(meta.utf8), metaURL)
    }

    return Result(skills: [
      SkillResult(
        status: .imported(skillRoot: skillRoot, contentHash: contentHash, createdMeta: createdMeta),
        skillName: skillName
      )
    ])
  }

  private func runLocalBatchImport(sourceRoot: URL) throws -> Result {
    let children = try fileSystemClient.contentsOfDirectory(sourceRoot)
      .filter { fileSystemClient.isDirectory($0.path) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    var skills: [SkillResult] = []
    for child in children {
      let childSkillMd = child.appendingPathComponent("SKILL.md")
      guard fileSystemClient.fileExists(childSkillMd.path),
        !fileSystemClient.isDirectory(childSkillMd.path)
      else {
        skills.append(SkillResult(status: .skippedInvalid(reason: "no SKILL.md"), skillName: child.lastPathComponent))
        continue
      }

      do {
        let singleResult = try runLocalSingleImport(sourceRoot: child)
        skills.append(contentsOf: singleResult.skills)
      } catch Error.skillAlreadyExists {
        skills.append(SkillResult(status: .skippedExists, skillName: child.lastPathComponent))
      } catch {
        skills.append(
          SkillResult(
            status: .skippedInvalid(reason: String(describing: error)),
            skillName: child.lastPathComponent
          ))
      }
    }

    // A batch succeeds if at least one child was imported or recognized as existing.
    // All-skippedInvalid means the parent had no valid skills at all.
    guard
      skills.contains(where: \.status.isImported)
        || skills.contains(where: { $0.status == .skippedExists })
    else {
      throw Error.noSkillsFound(sourceRoot.path)
    }

    return Result(skills: skills)
  }

  private func runGitHubImport(source: GitHubSkillSource) throws -> Result {
    let fetched = try githubSkillClient.fetch(source)

    if fetched.files["SKILL.md"] != nil {
      return try runGitHubSingleImport(source: source, fetched: fetched)
    }

    return try runGitHubBatchImport(source: source, fetched: fetched)
  }

  private func runGitHubSingleImport(
    source: GitHubSkillSource,
    fetched: GitHubSkillClient.FetchResult
  ) throws -> Result {
    let skillName = URL(filePath: source.skillPath, directoryHint: .isDirectory).lastPathComponent
    let skillRoot = try self.destinationRoot(for: skillName)
    try fileSystemClient.createDirectory(skillRoot, true)

    for key in fetched.files.keys.sorted() {
      guard let sanitized = SkillRelativePath.sanitize(key) else {
        throw Error.invalidGitHubSkillPath(key)
      }
      if sanitized == ".meta.toml" { continue }
      guard let data = fetched.files[key] else { continue }
      let destination = skillRoot.appendingPathComponent(sanitized)
      try fileSystemClient.createDirectory(destination.deletingLastPathComponent(), true)
      try fileSystemClient.write(data, destination)
    }

    let contentHash = try SkillContentHashFeature().run(skillDirectory: skillRoot)
    let createdAt = Self.formatDate(now)
    let meta = Self.defaultGitHubMeta(
      createdAt: createdAt,
      contentHash: contentHash,
      repo: source.repo,
      skillPath: source.skillPath,
      ref: fetched.resolvedRef,
      commit: fetched.commit
    )
    try fileSystemClient.write(Data(meta.utf8), skillRoot.appendingPathComponent(".meta.toml"))

    return Result(skills: [
      SkillResult(
        status: .imported(skillRoot: skillRoot, contentHash: contentHash, createdMeta: true),
        skillName: skillName
      )
    ])
  }

  private func runGitHubBatchImport(
    source: GitHubSkillSource,
    fetched: GitHubSkillClient.FetchResult
  ) throws -> Result {
    // Group files by first path component (child directory name)
    var groups: [String: [String: Data]] = [:]
    for (path, data) in fetched.files {
      let components = path.split(separator: "/", maxSplits: 1)
      guard components.count == 2 else { continue }
      let childName = String(components[0])
      let childRelativePath = String(components[1])
      groups[childName, default: [:]][childRelativePath] = data
    }

    var skills: [SkillResult] = []
    for childName in groups.keys.sorted() {
      let childFiles = groups[childName]!
      guard childFiles["SKILL.md"] != nil else {
        skills.append(SkillResult(status: .skippedInvalid(reason: "no SKILL.md"), skillName: childName))
        continue
      }

      let childSkillPath =
        source.skillPath.hasSuffix("/")
        ? "\(source.skillPath)\(childName)"
        : "\(source.skillPath)/\(childName)"

      do {
        let childSource = try GitHubSkillSource(repo: source.repo, skillPath: childSkillPath, ref: source.ref)
        let childFetched = GitHubSkillClient.FetchResult(
          files: childFiles,
          resolvedRef: fetched.resolvedRef,
          commit: fetched.commit
        )
        let singleResult = try runGitHubSingleImport(source: childSource, fetched: childFetched)
        skills.append(contentsOf: singleResult.skills)
      } catch Error.skillAlreadyExists {
        skills.append(SkillResult(status: .skippedExists, skillName: childName))
      } catch {
        skills.append(
          SkillResult(
            status: .skippedInvalid(reason: String(describing: error)),
            skillName: childName
          ))
      }
    }

    guard
      skills.contains(where: \.status.isImported)
        || skills.contains(where: { $0.status == .skippedExists })
    else {
      throw Error.noSkillsFound(source.skillPath)
    }

    return Result(skills: skills)
  }

  private func destinationRoot(for skillName: String) throws -> URL {
    let skillRoot = pathClient.skillsyncRoot()
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(skillName, isDirectory: true)
    guard !fileSystemClient.fileExists(skillRoot.path) else {
      throw Error.skillAlreadyExists(skillName)
    }
    return skillRoot
  }

  private static func defaultImportedMeta(createdAt: String, contentHash: String) -> String {
    """
    [skill]
    created = "\(createdAt)"
    source = "imported"
    version = 1
    content-hash = "\(contentHash)"
    state = "active"
    """
  }

  private static func defaultGitHubMeta(
    createdAt: String,
    contentHash: String,
    repo: String,
    skillPath: String,
    ref: String,
    commit: String
  ) -> String {
    """
    [skill]
    created = "\(createdAt)"
    source = "github"
    version = 1
    content-hash = "\(contentHash)"
    state = "active"

    [upstream]
    repo = "\(escaped(repo))"
    skill-path = "\(escaped(skillPath))"
    ref = "\(escaped(ref))"
    commit = "\(escaped(commit))"
    base-content-hash = "\(contentHash)"
    """
  }

  // These values are expected to be single-line Git metadata, but we still
  // escape common control characters to keep generated TOML valid.
  private static func escaped(_ value: String) -> String {
    value.replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
      .replacingOccurrences(of: "\t", with: "\\t")
  }

  private static func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
  }
}
