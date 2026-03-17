import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

private let testRegistry: [AgentRegistryEntry] = [
  .init(
    id: "claude-code", displayName: "Claude Code",
    globalSkillsPath: "~/.claude/skills", projectDirectory: ".claude",
    defaultLinkMode: "symlink"
  ),
  .init(
    id: "codex", displayName: "Codex CLI",
    globalSkillsPath: "~/.codex/skills", projectDirectory: ".codex",
    defaultLinkMode: "symlink"
  ),
  .init(
    id: "cursor", displayName: "Cursor",
    globalSkillsPath: "~/.cursor/skills", projectDirectory: ".cursor",
    defaultLinkMode: "hardlink"
  ),
]

private let testRegistryClient = AgentRegistryClient(
  entryFor: { id in testRegistry.first { $0.id == id } },
  allEntries: { testRegistry },
  projectDirectories: {
    Dictionary(uniqueKeysWithValues: testRegistry.map { ($0.id, $0.projectDirectory) })
  }
)

@Suite
struct TargetFeaturesTests {
  @Test
  func addToolPersistsTarget() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.agentRegistryClient = testRegistryClient
    } operation: {
      try TargetAddFeature().run(.init(mode: .tool("codex")))
    }

    expectNoDifference(
      result.added,
      [.init(id: "codex", path: "~/.codex/skills", source: .tool)]
    )
    let config = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LoadSyncConfigFeature().run()
    }
    expectNoDifference(config.targets, result.added)
  }

  @Test
  func addToolThrowsForUnknownTool() {
    let fileSystem = InMemoryFileSystem()

    #expect(throws: TargetAddFeature.Error.unknownTool("unknown", available: testRegistry)) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.agentRegistryClient = testRegistryClient
      } operation: {
        try TargetAddFeature().run(.init(mode: .tool("unknown")))
      }
    }
  }

  @Test
  func addPathThrowsForDuplicateResolvedPath() throws {
    let fileSystem = InMemoryFileSystem()
    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.agentRegistryClient = testRegistryClient
    } operation: {
      try TargetAddFeature().run(.init(mode: .path("/tmp/custom")))
    }

    #expect(throws: TargetAddFeature.Error.duplicatePath("/tmp/custom")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.agentRegistryClient = testRegistryClient
      } operation: {
        try TargetAddFeature().run(.init(mode: .path("/tmp/custom/./")))
      }
    }
  }

  @Test
  func addProjectFindsTargetsAndSkipsDuplicates() throws {
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
      at: URL(filePath: "/Users/blob/work/app/.claude/skills", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/work/app/Features", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SaveSyncConfigFeature().run(
        .init(
          targets: [.init(id: "existing-claude", path: "/Users/blob/work/app/.claude/skills", source: .path)],
          observation: .default
        )
      )
    }

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/work/app/Features", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.agentRegistryClient = testRegistryClient
    } operation: {
      try TargetAddFeature().run(.init(mode: .project))
    }

    expectNoDifference(
      result.added.map(\.path),
      ["/Users/blob/work/app/.codex/skills"]
    )
    expectNoDifference(
      result.skipped,
      ["/Users/blob/work/app/.claude/skills"]
    )
    #expect(fileSystem.client.fileExists("/Users/blob/work/app/.codex/skills"))
  }

  @Test
  func removeAndListTargets() throws {
    let fileSystem = InMemoryFileSystem()
    try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SaveSyncConfigFeature().run(
        .init(
          targets: [
            .init(id: "codex", path: "~/.codex/skills", source: .tool),
            .init(id: "path-1", path: "/tmp/custom", source: .path),
          ],
          observation: .default
        )
      )
    }

    let removed = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try TargetRemoveFeature().run(.init(id: "codex"))
    }
    expectNoDifference(removed.removed.id, "codex")

    let listed = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try TargetListFeature().run()
    }
    expectNoDifference(
      listed.targets,
      [.init(id: "path-1", path: "/tmp/custom", source: .path)]
    )
  }
}
