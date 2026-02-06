import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct AddCommandTests {
    @Test
    func importsSkill() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/project/existing-skill", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )
      try fileSystem.write(
        Data("# Existing Skill\n".utf8),
        to: URL(filePath: "/Users/blob/project/existing-skill/SKILL.md")
      )

      try await assertCommand(
        ["add", "existing-skill"],
        stdout: {
          """
          Imported skill existing-skill to /Users/blob/.skillsync/skills/existing-skill
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
        }
      )
    }

    @Test
    func missingSkillMarkdownThrowsActionableError() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try? fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/project/no-skill", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      await assertCommandThrows(
        ["add", "no-skill"],
        error: {
          """
          Skill directory '/Users/blob/project/no-skill' must contain SKILL.md.
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
