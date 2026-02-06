import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct ResolveSyncDestinationsFeatureTests {
  @Test
  func resolvesKnownToolsFromConfigBeforeDefaults() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/tmp/custom-codex-skills", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try ResolveSyncDestinationsFeature().run(
        .init(
          tools: ["codex"],
          paths: [],
          configuredTools: ["codex": "/tmp/custom-codex-skills"]
        )
      )
    }

    expectNoDifference(
      result.destinations,
      [
        .init(
          id: "codex",
          path: URL(filePath: "/tmp/custom-codex-skills", directoryHint: .isDirectory),
          source: .tool("codex")
        )
      ]
    )
  }

  @Test
  func throwsForUnknownTool() {
    let fileSystem = InMemoryFileSystem()
    #expect(throws: ResolveSyncDestinationsFeature.Error.unknownTool("unknown")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try ResolveSyncDestinationsFeature().run(
          .init(tools: ["unknown"], paths: [])
        )
      }
    }
  }

  @Test
  func resolvesExplicitPath() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/tmp/custom-path", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try ResolveSyncDestinationsFeature().run(
        .init(tools: [], paths: ["/tmp/custom-path"])
      )
    }

    expectNoDifference(
      result.destinations,
      [
        .init(
          id: "path-1",
          path: URL(filePath: "/tmp/custom-path", directoryHint: .isDirectory),
          source: .path("/tmp/custom-path")
        )
      ]
    )
  }

  @Test
  func resolvesMixedToolAndPath() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.codex/skills", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/tmp/custom-path", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try ResolveSyncDestinationsFeature().run(
        .init(
          tools: ["codex"],
          paths: ["/tmp/custom-path"]
        )
      )
    }

    expectNoDifference(
      result.destinations.map { "\($0.id)=\($0.path.path)" },
      [
        "codex=/Users/blob/.codex/skills",
        "path-1=/tmp/custom-path",
      ]
    )
  }

  @Test
  func autodetectsExistingKnownTools() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.codex/skills", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.claude/skills", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try ResolveSyncDestinationsFeature().run(
        .init(tools: [], paths: [])
      )
    }

    expectNoDifference(
      result.destinations.map { $0.id },
      ["claude-code", "codex"]
    )
  }

  @Test
  func deduplicatesCanonicalPaths() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/tmp/skills", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try ResolveSyncDestinationsFeature().run(
        .init(
          tools: [],
          paths: ["/tmp/skills", "/tmp/skills/./"]
        )
      )
    }

    expectNoDifference(result.destinations.count, 1)
    expectNoDifference(result.destinations[0].path.path, "/tmp/skills")
  }

  @Test
  func throwsNoDestinationsFoundForAutodetectWithNoToolDirectories() {
    let fileSystem = InMemoryFileSystem()

    #expect(throws: ResolveSyncDestinationsFeature.Error.noDestinationsFound) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try ResolveSyncDestinationsFeature().run(
          .init(tools: [], paths: [])
        )
      }
    }
  }

  @Test
  func projectModeFindsGitRootAndCreatesMissingSkillsDirectories() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/work/app/.git", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/work/app/.codex", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/work/app/Sources/Feature", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/work/app/Sources/Feature", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try ResolveSyncDestinationsFeature().run(
        .init(
          tools: [],
          paths: [],
          project: true
        )
      )
    }

    expectNoDifference(
      result.destinations,
      [
        .init(
          id: "codex",
          path: URL(filePath: "/Users/blob/work/app/.codex/skills", directoryHint: .isDirectory),
          source: .tool("codex")
        )
      ]
    )
    #expect(fileSystem.client.fileExists("/Users/blob/work/app/.codex/skills"))
  }

  @Test
  func projectModeFallsBackToTopmostToolDirectoryAncestorWithoutGit() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/work/project/.cursor", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/work/project/app/Feature", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/work/project/app/Feature", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try ResolveSyncDestinationsFeature().run(
        .init(
          tools: [],
          paths: [],
          project: true
        )
      )
    }

    expectNoDifference(
      result.destinations,
      [
        .init(
          id: "cursor",
          path: URL(filePath: "/Users/blob/work/project/.cursor/skills", directoryHint: .isDirectory),
          source: .tool("cursor")
        )
      ]
    )
  }

  @Test
  func projectModeThrowsWhenNoRootMarkersFound() {
    let fileSystem = InMemoryFileSystem()

    #expect(throws: ResolveSyncDestinationsFeature.Error.projectRootNotFound) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/work/project/app", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try ResolveSyncDestinationsFeature().run(
          .init(
            tools: [],
            paths: [],
            project: true
          )
        )
      }
    }
  }
}
