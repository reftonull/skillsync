import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct DiffCommandTests {
    @Test
    func printsJsonDiff() async throws {
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
        Data("# pdf\n\nchanged\n".utf8),
        to: URL(filePath: "/Users/blob/.skillsync/editing/pdf/SKILL.md")
      )

      try await assertCommand(
        ["diff", "pdf"],
        stdout: {
          """
          {
            "changes" : [
              {
                "kind" : "text",
                "patch" : "  \\"\\"\\"\\n  # pdf\\n  \\n- TODO: Describe this skill.\\n+ changed\\n  \\n  \\"\\"\\"",
                "path" : "SKILL.md",
                "status" : "modified"
              }
            ],
            "skill" : "pdf",
            "summary" : {
              "added" : 0,
              "deleted" : 0,
              "modified" : 1
            }
          }
          """
        },
        dependencies: deps
      )
    }

    @Test
    func throwsWhenEditMissing() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      await assertCommandThrows(
        ["diff", "pdf"],
        error: {
          """
          Skill 'pdf' not found.
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
