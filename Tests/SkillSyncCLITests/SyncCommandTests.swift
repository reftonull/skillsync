import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct SyncCommandTests {
    @Test
    func syncsConfiguredTargets() async throws {
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

          [observation]
          mode = "off"
          threshold = 0.3
          min_invocations = 5

          [[targets]]
          id = "codex"
          path = "/Users/blob/.codex/skills"
          source = "tool"
          """.utf8
        ),
        atPath: "/Users/blob/.skillsync/config.toml"
      )

      try await assertCommand(
        ["sync"],
        stdout: {
          """
          target=codex path=/Users/blob/.codex/skills status=ok skills=0
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
        }
      )
    }

    @Test
    func printsResolvedPathAndConfiguredPathWhenDifferent() async throws {
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

          [observation]
          mode = "off"
          threshold = 0.3
          min_invocations = 5

          [[targets]]
          id = "codex"
          path = "~/.codex/skills"
          source = "tool"
          """.utf8
        ),
        atPath: "/Users/blob/.skillsync/config.toml"
      )

      try await assertCommand(
        ["sync"],
        stdout: {
          """
          target=codex path=/Users/blob/.codex/skills status=ok skills=0 configured_path=~/.codex/skills
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
        }
      )
    }

    @Test
    func noTargetsConfiguredThrowsActionableError() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      await assertCommandThrows(
        ["sync"],
        error: {
          """
          No targets configured. Use `skillsync target add ...`.
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
        }
      )
    }
  }
}
