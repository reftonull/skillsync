import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct LoadSyncConfigFeatureTests {
  @Test
  func returnsEmptyWhenConfigIsMissing() throws {
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
      try LoadSyncConfigFeature().run()
    }

    expectNoDifference(result.configuredTools, [String: String]())
  }

  @Test
  func parsesToolPathsFromConfigToml() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    fileSystem.setFile(
      Data(
        """
        [skillsync]
        version = "1"

        [tools.codex]
        path = "/tmp/codex-skills"

        [tools.cursor]
        path = "~/custom-cursor-skills"

        [observation]
        mode = "auto"
        """.utf8
      ),
      atPath: "/Users/blob/.skillsync/config.toml"
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LoadSyncConfigFeature().run()
    }

    expectNoDifference(
      result.configuredTools,
      [
        "codex": "/tmp/codex-skills",
        "cursor": "~/custom-cursor-skills",
      ]
    )
  }

  @Test
  func ignoresToolsWithoutPath() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    fileSystem.setFile(
      Data(
        """
        [tools.codex]
        foo = "bar"

        [tools.cursor]
        path = "/tmp/cursor-skills"
        """.utf8
      ),
      atPath: "/Users/blob/.skillsync/config.toml"
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LoadSyncConfigFeature().run()
    }

    expectNoDifference(
      result.configuredTools,
      ["cursor": "/tmp/cursor-skills"]
    )
  }

  @Test
  func parseConfiguredToolsStripsCommentsSupportsSingleQuotesAndIgnoresEmptyToolName() {
    let parsed = LoadSyncConfigFeature.parseConfiguredTools(
      from: """
      [tools.codex]
      path = '/tmp/codex#skills' # inline comment should be ignored

      [tools.cursor]
      path = "~/cursor-skills" # trailing comment

      [tools.]
      path = "/tmp/ignored"
      """
    )

    expectNoDifference(
      parsed,
      [
        "codex": "/tmp/codex#skills",
        "cursor": "~/cursor-skills",
      ]
    )
  }

  @Test
  func returnsEmptyWhenConfigDataIsNotUtf8() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    fileSystem.setFile(
      Data([0xFF, 0xFE, 0x00, 0x80]),
      atPath: "/Users/blob/.skillsync/config.toml"
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LoadSyncConfigFeature().run()
    }

    expectNoDifference(result.configuredTools, [String: String]())
  }
}
