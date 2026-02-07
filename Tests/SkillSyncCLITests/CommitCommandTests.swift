import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct CommitCommandTests {
    @Test
    func commitsEditedSkill() async throws {
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
        ["new", "pdf"],
        stdout: {
          """
          Created skill pdf at /Users/blob/.skillsync/skills/pdf
          """
        },
        dependencies: deps
      )

      try await assertCommand(
        ["edit", "pdf"],
        stdout: {
          """
          Editing skill pdf at /Users/blob/.skillsync/editing/pdf
          """
        },
        dependencies: deps
      )

      try fileSystem.write(
        Data("# pdf\n\nCommitted from CLI\n".utf8),
        to: URL(filePath: "/Users/blob/.skillsync/editing/pdf/SKILL.md")
      )

      try await assertCommand(
        ["commit", "pdf", "--reason", "Refine phrasing"],
        stdout: {
          """
          Committed skill pdf version=2
          """
        },
        dependencies: deps
      )
    }

    @Test
    func failsWithoutLock() async throws {
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
        ["new", "pdf"],
        stdout: {
          """
          Created skill pdf at /Users/blob/.skillsync/skills/pdf
          """
        },
        dependencies: deps
      )

      await assertCommandThrows(
        ["commit", "pdf", "--reason", "Refine phrasing"],
        error: {
          """
          No active edit lock for 'pdf'. Lock file: /Users/blob/.skillsync/locks/pdf.lock
          """
        },
        dependencies: deps
      )
    }
  }
}
