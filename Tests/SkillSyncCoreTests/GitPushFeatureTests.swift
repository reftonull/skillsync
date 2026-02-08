import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct GitPushFeatureTests {
  @Test
  func commitsAndPushesWhenThereAreStagedChanges() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/.git", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    let commands = LockIsolated<[[String]]>([])

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.gitClient = GitClient(
        run: { _, arguments in
          commands.withValue { $0.append(arguments) }
          if arguments == ["add", "-A"] {
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
          if arguments == ["diff", "--cached", "--quiet"] {
            return .init(exitCode: 1, stdout: "", stderr: "")
          }
          if arguments == ["commit", "-m", "skillsync: update skills"] {
            return .init(exitCode: 0, stdout: "[main abc123] skillsync: update skills", stderr: "")
          }
          if arguments == ["push", "--set-upstream", "origin", "HEAD"] {
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
          Issue.record("Unexpected git command: \(arguments)")
          return .init(exitCode: 1, stdout: "", stderr: "unexpected")
        }
      )
    } operation: {
      try GitPushFeature().run(
        .init(remoteName: "origin", message: nil)
      )
    }

    expectNoDifference(result.remoteName, "origin")
    expectNoDifference(result.committed, true)
    expectNoDifference(result.commitMessage, "skillsync: update skills")
    expectNoDifference(
      commands.value,
      [
        ["add", "-A"],
        ["diff", "--cached", "--quiet"],
        ["commit", "-m", "skillsync: update skills"],
        ["push", "--set-upstream", "origin", "HEAD"],
      ]
    )
  }

  @Test
  func pushesWithoutCommitWhenNoChanges() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/.git", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    let commands = LockIsolated<[[String]]>([])

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.gitClient = GitClient(
        run: { _, arguments in
          commands.withValue { $0.append(arguments) }
          if arguments == ["add", "-A"] {
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
          if arguments == ["diff", "--cached", "--quiet"] {
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
          if arguments == ["push", "--set-upstream", "origin", "HEAD"] {
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
          Issue.record("Unexpected git command: \(arguments)")
          return .init(exitCode: 1, stdout: "", stderr: "unexpected")
        }
      )
    } operation: {
      try GitPushFeature().run(
        .init(remoteName: "origin", message: "  ")
      )
    }

    expectNoDifference(result.committed, false)
    expectNoDifference(result.commitMessage, nil)
    expectNoDifference(
      commands.value,
      [
        ["add", "-A"],
        ["diff", "--cached", "--quiet"],
        ["push", "--set-upstream", "origin", "HEAD"],
      ]
    )
  }

  @Test
  func throwsWhenRepositoryMissing() {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try? fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    #expect(
      throws: GitPushFeature.Error.notGitRepository("/Users/blob/.skillsync")
    ) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try GitPushFeature().run(
          .init(remoteName: "origin", message: nil)
        )
      }
    }
  }
}
