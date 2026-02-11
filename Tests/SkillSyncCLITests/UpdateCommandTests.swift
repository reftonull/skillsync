import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct UpdateCommandTests {
    @Test
    func updatesGitHubSkill() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/review-assistant", directoryHint: .isDirectory)
      try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
      try fileSystem.write(Data("# old\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))
      let baseHash = try hashSkill(skillRoot: skillRoot, fileSystem: fileSystem)
      try fileSystem.write(
        Data(
          """
          [skill]
          source = "github"
          version = 1
          content-hash = "\(baseHash)"
          state = "active"

          [upstream]
          repo = "acme/skills"
          skill-path = "skills/review-assistant"
          ref = "main"
          commit = "oldcommit"
          base-content-hash = "\(baseHash)"
          """.utf8
        ),
        to: skillRoot.appendingPathComponent(".meta.toml")
      )

      try await assertCommand(
        ["update", "review-assistant"],
        stdout: {
          """
          Updated skill review-assistant in /Users/blob/.skillsync/skills/review-assistant
          Run `skillsync sync` to apply changes to configured targets.
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.githubSkillClient = GitHubSkillClient { _ in
            .init(
              files: ["SKILL.md": Data("# new\n".utf8)],
              resolvedRef: "main",
              commit: "newcommit"
            )
          }
        }
      )
    }

    @Test
    func reportsUpToDate() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/review-assistant", directoryHint: .isDirectory)
      try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
      try fileSystem.write(Data("# same\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))
      let baseHash = try hashSkill(skillRoot: skillRoot, fileSystem: fileSystem)
      try fileSystem.write(
        Data(
          """
          [skill]
          source = "github"
          version = 1
          content-hash = "\(baseHash)"
          state = "active"

          [upstream]
          repo = "acme/skills"
          skill-path = "skills/review-assistant"
          ref = "main"
          commit = "oldcommit"
          base-content-hash = "\(baseHash)"
          """.utf8
        ),
        to: skillRoot.appendingPathComponent(".meta.toml")
      )

      try await assertCommand(
        ["update", "review-assistant"],
        stdout: {
          """
          Skill review-assistant is already up to date.
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.githubSkillClient = GitHubSkillClient { _ in
            .init(
              files: ["SKILL.md": Data("# same\n".utf8)],
              resolvedRef: "main",
              commit: "newcommit"
            )
          }
        }
      )
    }

    @Test
    func forceUpdatesDivergedSkill() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/review-assistant", directoryHint: .isDirectory)
      try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
      try fileSystem.write(Data("# old\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))
      let baseHash = try hashSkill(skillRoot: skillRoot, fileSystem: fileSystem)
      try fileSystem.write(Data("# local edits\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))
      try fileSystem.write(
        Data(
          """
          [skill]
          source = "github"
          version = 1
          content-hash = "\(baseHash)"
          state = "active"

          [upstream]
          repo = "acme/skills"
          skill-path = "skills/review-assistant"
          ref = "main"
          commit = "oldcommit"
          base-content-hash = "\(baseHash)"
          """.utf8
        ),
        to: skillRoot.appendingPathComponent(".meta.toml")
      )

      try await assertCommand(
        ["update", "review-assistant", "--force"],
        stdout: {
          """
          Updated skill review-assistant in /Users/blob/.skillsync/skills/review-assistant
          Run `skillsync sync` to apply changes to configured targets.
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.githubSkillClient = GitHubSkillClient { _ in
            .init(
              files: ["SKILL.md": Data("# upstream\n".utf8)],
              resolvedRef: "main",
              commit: "newcommit"
            )
          }
        }
      )
    }

    private func hashSkill(skillRoot: URL, fileSystem: InMemoryFileSystem) throws -> String {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try SkillContentHashFeature().run(skillDirectory: skillRoot)
      }
    }
  }
}
