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
          Run `skillsync sync` to apply changes to configured targets.
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
    func emptyDirectoryThrowsActionableError() async {
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
          No skill directories found in '/Users/blob/project/no-skill'.
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
    func importsSkillFromGitHubRepoAndPath() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      try await assertCommand(
        ["add", "--force", "github", "acme/skills", "skills/review-assistant", "main"],
        stdout: {
          """
          Imported skill review-assistant to /Users/blob/.skillsync/skills/review-assistant
          Run `skillsync sync` to apply changes to configured targets.
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.githubSkillClient = GitHubSkillClient { source in
            #expect(source.repo == "acme/skills")
            #expect(source.skillPath == "skills/review-assistant")
            #expect(source.ref == "main")
            return .init(
              files: [
                "SKILL.md": Data("# review-assistant\n".utf8)
              ],
              resolvedRef: "main",
              commit: "abc123"
            )
          }
          $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
        }
      )
    }

    @Test
    func importsSkillFromGitHubWithDefaultRef() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      try await assertCommand(
        ["add", "github", "acme/skills", "skills/review-assistant"],
        stdout: {
          """
          Imported skill review-assistant to /Users/blob/.skillsync/skills/review-assistant
          Run `skillsync sync` to apply changes to configured targets.
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.confirmationClient = ConfirmationClient(confirm: { _ in true })
          $0.githubSkillClient = GitHubSkillClient { source in
            #expect(source.repo == "acme/skills")
            #expect(source.skillPath == "skills/review-assistant")
            #expect(source.ref == "main")
            return .init(
              files: [
                "SKILL.md": Data("# review-assistant\n".utf8)
              ],
              resolvedRef: "main",
              commit: "abc123"
            )
          }
          $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
        }
      )
    }

    @Test
    func cancelsGitHubImportWhenNotConfirmed() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      try await assertCommand(
        ["add", "github", "acme/skills", "skills/review-assistant"],
        stdout: {
          """
          Cancelled GitHub import.
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.confirmationClient = ConfirmationClient(confirm: { _ in false })
          $0.githubSkillClient = GitHubSkillClient { _ in
            Issue.record("GitHub fetch should not run when import is not confirmed.")
            return .init(
              files: ["SKILL.md": Data("# review-assistant\n".utf8)],
              resolvedRef: "main",
              commit: "abc123"
            )
          }
        }
      )
    }

    @Test
    func forceSkipsGitHubConfirmation() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      try await assertCommand(
        ["add", "--force", "github", "acme/skills", "skills/review-assistant"],
        stdout: {
          """
          Imported skill review-assistant to /Users/blob/.skillsync/skills/review-assistant
          Run `skillsync sync` to apply changes to configured targets.
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.confirmationClient = ConfirmationClient(confirm: { _ in
            Issue.record("Confirmation should be skipped when --force is set.")
            return false
          })
          $0.githubSkillClient = GitHubSkillClient { source in
            #expect(source.repo == "acme/skills")
            #expect(source.skillPath == "skills/review-assistant")
            #expect(source.ref == "main")
            return .init(
              files: ["SKILL.md": Data("# review-assistant\n".utf8)],
              resolvedRef: "main",
              commit: "abc123"
            )
          }
          $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
        }
      )
    }

    @Test
    func batchImportShowsPerSkillStatusAndSummary() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      // Parent with alpha (valid), beta (valid), gamma (no SKILL.md)
      let parent = "/Users/blob/project/all-skills"
      for name in ["alpha", "beta", "gamma"] {
        try fileSystem.createDirectory(
          at: URL(filePath: "\(parent)/\(name)", directoryHint: .isDirectory),
          withIntermediateDirectories: true
        )
      }
      try fileSystem.write(Data("# Alpha\n".utf8), to: URL(filePath: "\(parent)/alpha/SKILL.md"))
      try fileSystem.write(Data("# Beta\n".utf8), to: URL(filePath: "\(parent)/beta/SKILL.md"))

      try await assertCommand(
        ["add", "all-skills"],
        stdout: {
          """
          Imported alpha
          Imported beta
          Skipped gamma (no SKILL.md)

          Imported 2 skills, skipped 1.
          Run `skillsync sync` to apply changes to configured targets.
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
    func batchImportShowsSkippedExistsStatus() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      let parent = "/Users/blob/project/all-skills"
      for name in ["alpha", "beta"] {
        try fileSystem.createDirectory(
          at: URL(filePath: "\(parent)/\(name)", directoryHint: .isDirectory),
          withIntermediateDirectories: true
        )
        try fileSystem.write(
          Data("# \(name)\n".utf8),
          to: URL(filePath: "\(parent)/\(name)/SKILL.md")
        )
      }

      // Pre-create beta in canonical store
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.skillsync/skills/beta", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["add", "all-skills"],
        stdout: {
          """
          Imported alpha
          Skipped beta (already exists)

          Imported 1 skills, skipped 1.
          Run `skillsync sync` to apply changes to configured targets.
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
    func forceIsRejectedForLocalPathMode() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      await assertCommandThrows(
        ["add", "--force", "existing-skill"],
        error: {
          """
          `--force` is only supported for `skillsync add github ...`.
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
