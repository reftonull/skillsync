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

    expectNoDifference(result.targets, [SyncTarget]())
    expectNoDifference(result.observation, .default)
  }

  @Test
  func parsesTargetsFromConfigToml() throws {
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

        [[targets]]
        id = "codex"
        path = "/tmp/codex-skills"
        source = "tool"

        [[targets]]
        id = "project-codex"
        path = "~/project/.codex/skills"
        source = "project"

        [observation]
        mode = "on"
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
      result.targets,
      [
        .init(id: "codex", path: "/tmp/codex-skills", source: .tool),
        .init(id: "project-codex", path: "~/project/.codex/skills", source: .project),
      ]
    )
    expectNoDifference(
      result.observation,
      .init(mode: .on)
    )
  }

  @Test
  func ignoresInvalidTargetRows() throws {
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
        [[targets]]
        id = "broken"
        foo = "bar"

        [[targets]]
        id = "cursor"
        path = "/tmp/cursor-skills"
        source = "tool"
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
      result.targets,
      [.init(id: "cursor", path: "/tmp/cursor-skills", source: .tool)]
    )
  }

  @Test
  func parseTargetsStripsCommentsAndSupportsSingleQuotes() {
    let parsed = LoadSyncConfigFeature.parseTargets(
      from: """
      [[targets]]
      id = 'codex'
      path = '/tmp/codex#skills' # inline comment should be ignored
      source = "tool"

      [[targets]]
      id = "cursor"
      path = "~/cursor-skills" # trailing comment
      source = "path"
      """
    )

    expectNoDifference(
      parsed,
      [
        .init(id: "codex", path: "/tmp/codex#skills", source: .tool),
        .init(id: "cursor", path: "~/cursor-skills", source: .path),
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

    expectNoDifference(result.targets, [SyncTarget]())
    expectNoDifference(result.observation, .default)
  }

  @Test
  func parsesObservationSettingsFromConfig() throws {
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
        [observation]
        mode = "off"
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
      result.observation,
      .init(mode: .off)
    )
  }

  @Test
  func fallsBackToDefaultWhenObservationModeIsUnknown() throws {
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
        [observation]
        mode = "invalid"
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
      result.observation,
      .default
    )
  }
}
