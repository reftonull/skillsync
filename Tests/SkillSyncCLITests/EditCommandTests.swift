import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct EditCommandTests {
    @Test
    func preparesEditingWorkspace() async throws {
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
    }

    @Test
    func reportsLockConflict() async throws {
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

      await assertCommandThrows(
        ["edit", "pdf"],
        error: {
          """
          Skill 'pdf' is already being edited. Lock file: /Users/blob/.skillsync/locks/pdf.lock
          """
        },
        dependencies: deps
      )
    }

    @Test
    func forceTakesOverLockedEdit() async throws {
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
        Data("# pdf\n\nnew canonical\n".utf8),
        to: URL(filePath: "/Users/blob/.skillsync/skills/pdf/SKILL.md")
      )

      try await assertCommand(
        ["edit", "pdf", "--force"],
        stdout: {
          """
          Editing skill pdf at /Users/blob/.skillsync/editing/pdf
          """
        },
        dependencies: deps
      )

      let edited = try fileSystem.data(at: URL(filePath: "/Users/blob/.skillsync/editing/pdf/SKILL.md"))
      #expect(String(decoding: edited, as: UTF8.self).contains("new canonical"))
    }
  }
}
