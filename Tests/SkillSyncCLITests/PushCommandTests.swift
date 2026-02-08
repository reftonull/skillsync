import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct PushCommandTests {
    @Test
    func commitsAndPushes() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.skillsync/.git", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["push", "-m", "Update skill docs"],
        stdout: {
          """
          Committed changes: Update skill docs
          Pushed /Users/blob/.skillsync to origin.
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
              if arguments == ["add", "-A"] {
                return .init(exitCode: 0, stdout: "", stderr: "")
              }
              if arguments == ["diff", "--cached", "--quiet"] {
                return .init(exitCode: 1, stdout: "", stderr: "")
              }
              if arguments == ["commit", "-m", "Update skill docs"] {
                return .init(exitCode: 0, stdout: "", stderr: "")
              }
              if arguments == ["push", "--set-upstream", "origin", "HEAD"] {
                return .init(exitCode: 0, stdout: "", stderr: "")
              }
              return .init(exitCode: 1, stdout: "", stderr: "unexpected")
            }
          )
        }
      )
    }

    @Test
    func pushesWithoutCommitWhenNoChanges() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.skillsync/.git", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["push"],
        stdout: {
          """
          No local changes to commit.
          Pushed /Users/blob/.skillsync to origin.
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
              if arguments == ["add", "-A"] {
                return .init(exitCode: 0, stdout: "", stderr: "")
              }
              if arguments == ["diff", "--cached", "--quiet"] {
                return .init(exitCode: 0, stdout: "", stderr: "")
              }
              if arguments == ["push", "--set-upstream", "origin", "HEAD"] {
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
