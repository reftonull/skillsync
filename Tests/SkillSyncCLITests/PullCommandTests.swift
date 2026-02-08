import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct PullCommandTests {
    @Test
    func pullsAndSkipsSyncWhenNoTargetsConfigured() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.skillsync/.git", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["pull"],
        stdout: {
          """
          Pulled latest changes into /Users/blob/.skillsync
          No targets configured. Skipped sync.
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.gitClient = GitClient(
            run: { _, arguments in
              if arguments == ["pull", "--ff-only"] {
                return .init(exitCode: 0, stdout: "", stderr: "")
              }
              return .init(exitCode: 1, stdout: "", stderr: "unexpected")
            }
          )
        }
      )
    }

    @Test
    func pullsAndRunsSyncWhenTargetsConfigured() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.skillsync/.git", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )
      fileSystem.setFile(
        Data(
          """
          [skillsync]
          version = "1"

          [observation]
          mode = "off"

          [[targets]]
          id = "codex"
          path = "~/.codex/skills"
          source = "tool"
          """.utf8
        ),
        atPath: "/Users/blob/.skillsync/config.toml"
      )

      try await assertCommand(
        ["pull"],
        stdout: {
          """
          Pulled latest changes into /Users/blob/.skillsync
          [ok]   codex   /Users/blob/.codex/skills   (0 skills)
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.gitClient = GitClient(
            run: { _, arguments in
              if arguments == ["pull", "--ff-only"] {
                return .init(exitCode: 0, stdout: "", stderr: "")
              }
              return .init(exitCode: 1, stdout: "", stderr: "unexpected")
            }
          )
        }
      )
    }
  }
}
