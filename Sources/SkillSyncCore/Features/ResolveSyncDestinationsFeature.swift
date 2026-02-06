import Dependencies
import Foundation

public struct SyncDestination: Equatable, Sendable {
  public enum Source: Equatable, Sendable {
    case tool(String)
    case path(String)
  }

  public var id: String
  public var path: URL
  public var source: Source

  public init(id: String, path: URL, source: Source) {
    self.id = id
    self.path = path
    self.source = source
  }
}

public struct ResolveSyncDestinationsFeature {
  public struct Input: Equatable, Sendable {
    public var tools: [String]
    public var paths: [String]
    public var project: Bool
    public var configuredTools: [String: String]

    public init(
      tools: [String],
      paths: [String],
      project: Bool = false,
      configuredTools: [String: String] = [:]
    ) {
      self.tools = tools
      self.paths = paths
      self.project = project
      self.configuredTools = configuredTools
    }
  }

  public struct Result: Equatable, Sendable {
    public var destinations: [SyncDestination]

    public init(destinations: [SyncDestination]) {
      self.destinations = destinations
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case unknownTool(String)
    case missingPath(String)
    case projectRootNotFound
    case noDestinationsFound

    public var description: String {
      switch self {
      case let .unknownTool(name):
        return "Unknown tool '\(name)'. Pass --path or configure [tools.\(name)].path."
      case let .missingPath(path):
        return "Destination path does not exist: \(path)"
      case .projectRootNotFound:
        return "Could not determine project root from current directory."
      case .noDestinationsFound:
        return "No sync destinations found. Pass --tool or --path."
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    var candidates: [SyncDestination] = []

    if input.project {
      let projectDestinations = try self.resolveProjectDestinations()
      candidates.append(contentsOf: projectDestinations)
    }

    if input.tools.isEmpty && input.paths.isEmpty && !input.project {
      let configured = input.configuredTools
      var known = Self.defaultToolPaths
      for (name, path) in configured {
        known[name] = path
      }

      for tool in known.keys.sorted() {
        guard let configuredPath = known[tool] else { continue }
        let resolvedPath = pathClient.resolvePath(configuredPath)
        guard fileSystemClient.fileExists(resolvedPath.path) else { continue }
        candidates.append(
          SyncDestination(
            id: tool,
            path: resolvedPath,
            source: .tool(tool)
          )
        )
      }
    } else {
      for tool in input.tools {
        let path = input.configuredTools[tool] ?? Self.defaultToolPaths[tool]
        guard let path else {
          throw Error.unknownTool(tool)
        }
        let resolvedPath = pathClient.resolvePath(path)
        guard fileSystemClient.fileExists(resolvedPath.path) else {
          throw Error.missingPath(resolvedPath.path)
        }
        candidates.append(
          SyncDestination(
            id: tool,
            path: resolvedPath,
            source: .tool(tool)
          )
        )
      }

      for (offset, rawPath) in input.paths.enumerated() {
        let resolvedPath = pathClient.resolvePath(rawPath)
        guard fileSystemClient.fileExists(resolvedPath.path) else {
          throw Error.missingPath(resolvedPath.path)
        }
        candidates.append(
          SyncDestination(
            id: "path-\(offset + 1)",
            path: resolvedPath,
            source: .path(rawPath)
          )
        )
      }
    }

    var deduplicated: [SyncDestination] = []
    var seenPaths: Set<String> = []
    for destination in candidates {
      let normalized = destination.path.standardizedFileURL.path
      if seenPaths.insert(normalized).inserted {
        deduplicated.append(destination)
      }
    }

    guard !deduplicated.isEmpty else {
      throw Error.noDestinationsFound
    }

    return Result(destinations: deduplicated)
  }

  private func resolveProjectDestinations() throws -> [SyncDestination] {
    let projectRoot = try self.findProjectRoot()
    var destinations: [SyncDestination] = []
    for (toolName, directoryName) in Self.projectToolDirectories {
      let toolRoot = projectRoot.appendingPathComponent(directoryName, isDirectory: true)
      guard fileSystemClient.fileExists(toolRoot.path) else { continue }
      let skillsPath = toolRoot.appendingPathComponent("skills", isDirectory: true)
      if !fileSystemClient.fileExists(skillsPath.path) {
        try fileSystemClient.createDirectory(skillsPath, true)
      }
      destinations.append(
        SyncDestination(
          id: toolName,
          path: skillsPath,
          source: .tool(toolName)
        )
      )
    }
    return destinations
  }

  private func findProjectRoot() throws -> URL {
    var current = pathClient.currentDirectory().standardizedFileURL
    var toolDirectoryCandidate: URL?

    while true {
      let gitDirectory = current.appendingPathComponent(".git", isDirectory: true)
      if fileSystemClient.fileExists(gitDirectory.path) {
        return current
      }

      if Self.projectToolDirectories.values.contains(where: {
        let toolDirectory = current.appendingPathComponent($0, isDirectory: true)
        return fileSystemClient.fileExists(toolDirectory.path)
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

  public static let defaultToolPaths: [String: String] = [
    "claude-code": "~/.claude/skills",
    "codex": "~/.codex/skills",
    "cursor": "~/.cursor/skills",
  ]

  static let projectToolDirectories: [String: String] = [
    "claude-code": ".claude",
    "codex": ".codex",
    "cursor": ".cursor",
  ]
}
