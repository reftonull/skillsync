import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct GitRemoteSetFeatureTests {
  @Test
  func initializesRepositoryAndAddsRemoteWhenMissing() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let commands = LockIsolated<[[String]]>([])

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.builtInSkillsClient = BuiltInSkillsClient(load: { [] })
      $0.gitClient = GitClient(
        run: { _, arguments in
          commands.withValue { $0.append(arguments) }
          if arguments == ["init"] {
            try fileSystem.createDirectory(
              at: URL(filePath: "/Users/blob/.skillsync/.git", directoryHint: .isDirectory),
              withIntermediateDirectories: true
            )
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
          if arguments == ["remote", "get-url", "origin"] {
            return .init(exitCode: 2, stdout: "", stderr: "missing")
          }
          if arguments == ["remote", "add", "origin", "https://example.com/org/skills.git"] {
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
          Issue.record("Unexpected git command: \(arguments)")
          return .init(exitCode: 1, stdout: "", stderr: "unexpected")
        }
      )
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try GitRemoteSetFeature().run(
        .init(remoteName: "origin", remoteURL: "https://example.com/org/skills.git")
      )
    }

    expectNoDifference(result.remoteName, "origin")
    expectNoDifference(result.remoteURL, "https://example.com/org/skills.git")
    expectNoDifference(result.initializedRepository, true)
    expectNoDifference(result.action, .added)
    expectNoDifference(
      commands.value,
      [
        ["init"],
        ["remote", "get-url", "origin"],
        ["remote", "add", "origin", "https://example.com/org/skills.git"],
      ]
    )
  }

  @Test
  func updatesRemoteWhenRepositoryAlreadyExists() throws {
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
      $0.builtInSkillsClient = BuiltInSkillsClient(load: { [] })
      $0.gitClient = GitClient(
        run: { _, arguments in
          commands.withValue { $0.append(arguments) }
          if arguments == ["remote", "get-url", "origin"] {
            return .init(exitCode: 0, stdout: "https://old.example/repo.git\n", stderr: "")
          }
          if arguments == ["remote", "set-url", "origin", "https://example.com/org/skills.git"] {
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
          Issue.record("Unexpected git command: \(arguments)")
          return .init(exitCode: 1, stdout: "", stderr: "unexpected")
        }
      )
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try GitRemoteSetFeature().run(
        .init(remoteName: "origin", remoteURL: "https://example.com/org/skills.git")
      )
    }

    expectNoDifference(result.initializedRepository, false)
    expectNoDifference(result.action, .updated)
    expectNoDifference(
      commands.value,
      [
        ["remote", "get-url", "origin"],
        ["remote", "set-url", "origin", "https://example.com/org/skills.git"],
      ]
    )
  }

  @Test
  func rejectsEmptyRemoteName() {
    #expect(throws: GitRemoteSetFeature.Error.invalidRemoteName) {
      try GitRemoteSetFeature().run(
        .init(remoteName: "   ", remoteURL: "https://example.com/org/skills.git")
      )
    }
  }
}
