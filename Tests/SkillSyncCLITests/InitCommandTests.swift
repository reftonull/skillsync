import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct InitCommandTests {
    private static let fixtureBuiltInSkills: [BuiltInSkill] = [
      BuiltInSkill(
        name: "skillsync-new",
        files: ["SKILL.md": Data("# skillsync-new\n".utf8)]
      ),
      BuiltInSkill(
        name: "skillsync-check",
        files: ["SKILL.md": Data("# skillsync-check\n".utf8)]
      ),
      BuiltInSkill(
        name: "skillsync-refine",
        files: ["SKILL.md": Data("# skillsync-refine\n".utf8)]
      ),
    ]

    @Test
    func initializesStore() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      try await assertCommand(
        ["init"],
        stdout: {
          """
          Initialized skillsync store at /Users/blob/.skillsync
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.builtInSkillsClient = BuiltInSkillsClient(
            load: { Self.fixtureBuiltInSkills }
          )
          $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
        }
      )
    }

    @Test
    func secondRunIsNoop() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      let deps: (inout DependencyValues) throws -> Void = {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.builtInSkillsClient = BuiltInSkillsClient(
          load: { Self.fixtureBuiltInSkills }
        )
        $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
      }

      try await assertCommand(
        ["init"],
        stdout: {
          """
          Initialized skillsync store at /Users/blob/.skillsync
          """
        },
        dependencies: deps
      )

      try await assertCommand(
        ["init"],
        stdout: {
          """
          skillsync store already initialized at /Users/blob/.skillsync
          """
        },
        dependencies: deps
      )
    }
  }
}
