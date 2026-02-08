import ConcurrencyExtras
import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct GitPullFeatureTests {
  @Test
  func pullsAndThenSyncsConfiguredTargets() throws {
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
          if arguments == ["pull", "--ff-only"] {
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
          Issue.record("Unexpected git command: \(arguments)")
          return .init(exitCode: 1, stdout: "", stderr: "unexpected")
        }
      )
    } operation: {
      try GitPullFeature().run()
    }

    #expect(result.syncResult != nil)
    expectNoDifference(commands.value, [["pull", "--ff-only"]])
    let syncResult = try #require(result.syncResult)
    #expect(syncResult.targets.count == 1)
    let first = try #require(syncResult.targets.first)
    #expect(first.status == .ok)
    #expect(first.syncedSkills == 0)
  }

  @Test
  func skipsSyncWhenNoTargetsConfigured() throws {
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
          if arguments == ["pull", "--ff-only"] {
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
          Issue.record("Unexpected git command: \(arguments)")
          return .init(exitCode: 1, stdout: "", stderr: "unexpected")
        }
      )
    } operation: {
      try GitPullFeature().run()
    }

    expectNoDifference(commands.value, [["pull", "--ff-only"]])
    #expect(result.skippedSync)
    #expect(result.syncResult == nil)
  }

  @Test
  func throwsWhenStoreMissing() {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    #expect(
      throws: GitPullFeature.Error.storeNotInitialized("/Users/blob/.skillsync")
    ) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try GitPullFeature().run()
      }
    }
  }
}
