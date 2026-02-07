import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

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

    #expect(throws: TargetAddFeature.Error.unknownTool("unknown")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
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
