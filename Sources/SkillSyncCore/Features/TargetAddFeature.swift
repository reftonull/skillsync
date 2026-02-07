import Dependencies
import Foundation

public struct TargetAddFeature {
  public enum Mode: Equatable, Sendable {
    case tool(String)
    case path(String)
    case project
  }

  public struct Input: Equatable, Sendable {
    public var mode: Mode

    public init(mode: Mode) {
      self.mode = mode
    }
  }

  public struct Result: Equatable, Sendable {
    public var added: [SyncTarget]
    public var skipped: [String]

    public init(added: [SyncTarget], skipped: [String]) {
      self.added = added
      self.skipped = skipped
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case unknownTool(String)
    case duplicatePath(String)
    case projectRootNotFound
    case noProjectTargetsFound

    public var description: String {
      switch self {
      case let .unknownTool(name):
        return "Unknown tool '\(name)'. Known tools: claude-code, codex, cursor."
      case let .duplicatePath(path):
        return "A target already exists for path: \(path)"
      case .projectRootNotFound:
        return "Could not determine project root from current directory."
      case .noProjectTargetsFound:
        return "No project-local tool directories found at project root."
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let config = try LoadSyncConfigFeature().run()
    var targets = config.targets
    let existingResolvedPaths = Set(targets.map { resolvePath($0.path) })
    var added: [SyncTarget] = []
    var skipped: [String] = []

    switch input.mode {
    case let .tool(tool):
      guard let defaultPath = KnownTools.defaultPaths[tool] else {
        throw Error.unknownTool(tool)
      }
      let resolved = resolvePath(defaultPath)
      guard !existingResolvedPaths.contains(resolved) else {
        throw Error.duplicatePath(resolved)
      }
      let id = uniqueID(preferred: tool, existing: Set(targets.map(\.id)))
      let target = SyncTarget(id: id, path: defaultPath, source: .tool)
      targets.append(target)
      added.append(target)

    case let .path(rawPath):
      let resolved = resolvePath(rawPath)
      guard !existingResolvedPaths.contains(resolved) else {
        throw Error.duplicatePath(resolved)
      }
      let id = nextPathID(existing: Set(targets.map(\.id)))
      let target = SyncTarget(id: id, path: resolved, source: .path)
      targets.append(target)
      added.append(target)

    case .project:
      let projectRoot = try findProjectRoot()
      var anyDiscovered = false
      var seenPaths = existingResolvedPaths
      for tool in KnownTools.projectDirectories.keys.sorted() {
        guard let directoryName = KnownTools.projectDirectories[tool] else { continue }
        let toolRoot = projectRoot.appendingPathComponent(directoryName, isDirectory: true)
        guard fileSystemClient.fileExists(toolRoot.path), fileSystemClient.isDirectory(toolRoot.path) else {
          continue
        }
        anyDiscovered = true
        let skillsPath = toolRoot.appendingPathComponent("skills", isDirectory: true)
        if !fileSystemClient.fileExists(skillsPath.path) {
          try fileSystemClient.createDirectory(skillsPath, true)
        }
        let resolved = resolvePath(skillsPath.path)
        if seenPaths.contains(resolved) {
          skipped.append(resolved)
          continue
        }
        seenPaths.insert(resolved)
        let preferredID = "\(tool)-project"
        let id = uniqueID(preferred: preferredID, existing: Set(targets.map(\.id)))
        let target = SyncTarget(id: id, path: resolved, source: .project)
        targets.append(target)
        added.append(target)
      }
      guard anyDiscovered else {
        throw Error.noProjectTargetsFound
      }
    }

    try SaveSyncConfigFeature().run(
      .init(
        targets: targets,
        observation: config.observation
      )
    )
    return Result(added: added, skipped: skipped)
  }

  private func resolvePath(_ path: String) -> String {
    pathClient.resolvePath(path).standardizedFileURL.path
  }

  private func nextPathID(existing: Set<String>) -> String {
    var index = 1
    while true {
      let candidate = "path-\(index)"
      if !existing.contains(candidate) { return candidate }
      index += 1
    }
  }

  private func uniqueID(preferred: String, existing: Set<String>) -> String {
    if !existing.contains(preferred) {
      return preferred
    }
    var counter = 2
    while true {
      let candidate = "\(preferred)-\(counter)"
      if !existing.contains(candidate) { return candidate }
      counter += 1
    }
  }

  private func findProjectRoot() throws -> URL {
    var current = pathClient.currentDirectory().standardizedFileURL
    var toolDirectoryCandidate: URL?

    while true {
      let gitDirectory = current.appendingPathComponent(".git", isDirectory: true)
      if fileSystemClient.fileExists(gitDirectory.path) {
        return current
      }

      if KnownTools.projectDirectories.values.contains(where: { toolDirectory in
        fileSystemClient.fileExists(
          current.appendingPathComponent(toolDirectory, isDirectory: true).path
        )
      }) {
        toolDirectoryCandidate = current
      }

      let parent = current.deletingLastPathComponent().standardizedFileURL
      if parent.path == current.path {
        break
      }
      current = parent
    }

    if let toolDirectoryCandidate {
      return toolDirectoryCandidate
    }
    throw Error.projectRootNotFound
  }
}
