import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct LsFeatureTests {
  @Test
  func returnsEmptyWhenNoSkillsDirectoryExists() throws {
    let fileSystem = InMemoryFileSystem()

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LsFeature().run()
    }

    expectNoDifference(result.skills, [])
  }

  @Test
  func listsSkillsSortedWithStateAndStats() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      _ = try NewFeature().run(.init(name: "shell", description: nil))
      _ = try NewFeature().run(.init(name: "pdf", description: nil))
    }

    let shellMetaURL = URL(filePath: "/Users/blob/.skillsync/skills/shell/.meta.toml")
    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().run(
        metaURL: shellMetaURL,
        updates: [
          .init(section: "skill", key: "state", operation: .setString("pending_remove")),
          .init(section: "stats", key: "total-invocations", operation: .setInt(10)),
          .init(section: "stats", key: "positive", operation: .setInt(7)),
          .init(section: "stats", key: "negative", operation: .setInt(3)),
        ]
      )
    }

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LsFeature().run()
    }

    expectNoDifference(
      result.skills,
      [
        .init(name: "pdf", state: "active", totalInvocations: 0, positive: 0, negative: 0),
        .init(name: "shell", state: "pending_remove", totalInvocations: 10, positive: 7, negative: 3),
      ]
    )
  }
}
