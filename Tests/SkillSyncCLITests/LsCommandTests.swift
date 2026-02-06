import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct LsCommandTests {
    @Test
    func printsNoSkillsWhenEmpty() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      try await assertCommand(
        ["ls"],
        stdout: {
          """
          No skills found.
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
    func printsSkillsWithStateAndStats() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      let deps: (inout DependencyValues) throws -> Void = {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
      }

      try await assertCommand(
        ["new", "shell"],
        stdout: {
          """
          Created skill shell at /Users/blob/.skillsync/skills/shell
          """
        },
        dependencies: deps
      )
      try await assertCommand(
        ["new", "pdf"],
        stdout: {
          """
          Created skill pdf at /Users/blob/.skillsync/skills/pdf
          """
        },
        dependencies: deps
      )
      try await assertCommand(
        ["rm", "shell"],
        stdout: {
          """
          Marked skill shell for removal (pending prune on next sync)
          """
        },
        dependencies: deps
      )

      try await assertCommand(
        ["ls"],
        stdout: {
          """
          pdf state=active total=0 positive=0 negative=0
          shell state=pending_remove total=0 positive=0 negative=0
          """
        },
        dependencies: deps
      )
    }
  }
}
