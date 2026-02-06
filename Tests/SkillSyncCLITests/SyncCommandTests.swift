import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct SyncCommandTests {
    @Test
    func resolvesToolDestination() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.codex/skills", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["sync", "--tool", "codex"],
        stdout: {
          """
          destination=codex path=/Users/blob/.codex/skills
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
    func resolvesToolDestinationFromConfigOverride() async throws {
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
          path = "/tmp/custom-codex"
          """.utf8
        ),
        atPath: "/Users/blob/.skillsync/config.toml"
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/tmp/custom-codex", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["sync", "--tool", "codex"],
        stdout: {
          """
          destination=codex path=/tmp/custom-codex
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
    func resolvesMixedToolAndPathDestinations() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.codex/skills", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/tmp/custom-path", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["sync", "--tool", "codex", "--path", "/tmp/custom-path"],
        stdout: {
          """
          destination=codex path=/Users/blob/.codex/skills
          destination=path-1 path=/tmp/custom-path
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
    func unknownToolThrowsActionableError() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      await assertCommandThrows(
        ["sync", "--tool", "unknown"],
        error: {
          """
          Unknown tool 'unknown'. Pass --path or configure [tools.unknown].path.
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
    func missingPathThrowsActionableError() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      await assertCommandThrows(
        ["sync", "--path", "/tmp/does-not-exist"],
        error: {
          """
          Destination path does not exist: /tmp/does-not-exist
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
    func autodetectsToolsWhenNoFlagsProvided() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.claude/skills", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.codex/skills", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["sync"],
        stdout: {
          """
          destination=claude-code path=/Users/blob/.claude/skills
          destination=codex path=/Users/blob/.codex/skills
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
    func autodetectsConfiguredToolPaths() async throws {
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
          [tools.custom]
          path = "/tmp/custom-tool-skills"
          """.utf8
        ),
        atPath: "/Users/blob/.skillsync/config.toml"
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/tmp/custom-tool-skills", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["sync"],
        stdout: {
          """
          destination=custom path=/tmp/custom-tool-skills
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
    func projectFlagResolvesProjectToolPaths() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/work/app/.git", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/work/app/.claude", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/work/app/Features", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["sync", "--project"],
        stdout: {
          """
          destination=claude-code path=/Users/blob/work/app/.claude/skills
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/work/app/Features", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
        }
      )
    }

    @Test
    func projectFlagThrowsWhenNoProjectRoot() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      await assertCommandThrows(
        ["sync", "--project"],
        error: {
          """
          Could not determine project root from current directory.
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/work/feature", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
        }
      )
    }
  }
}
