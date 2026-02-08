import ConcurrencyExtras
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct RemoteCommandTests {
    @Test
    func setsOriginAndInitializesRepoWhenMissing() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      let commands = LockIsolated<[[String]]>([])

      try await assertCommand(
        ["remote", "set", "https://example.com/org/skills.git"],
        stdout: {
          """
          Initialized git repository at /Users/blob/.skillsync
          Added remote origin -> https://example.com/org/skills.git
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.builtInSkillsClient = BuiltInSkillsClient(load: { [] })
          $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
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
              return .init(exitCode: 1, stdout: "", stderr: "unexpected")
            }
          )
        }
      )

      #expect(
        commands.value == [
          ["init"],
          ["remote", "get-url", "origin"],
          ["remote", "add", "origin", "https://example.com/org/skills.git"],
        ]
      )
    }

    @Test
    func updatesNamedRemote() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.skillsync/.git", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )

      try await assertCommand(
        ["remote", "set", "--name", "upstream", "git@github.com:org/skills.git"],
        stdout: {
          """
          Updated remote upstream -> git@github.com:org/skills.git
          """
        },
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.builtInSkillsClient = BuiltInSkillsClient(load: { [] })
          $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
          $0.gitClient = GitClient(
            run: { _, arguments in
              if arguments == ["remote", "get-url", "upstream"] {
                return .init(exitCode: 0, stdout: "git@github.com:org/old.git", stderr: "")
              }
              if arguments == ["remote", "set-url", "upstream", "git@github.com:org/skills.git"] {
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
