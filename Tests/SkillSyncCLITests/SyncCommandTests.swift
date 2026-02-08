import ConcurrencyExtras
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct SyncCommandTests {
    @Test
    func syncsConfiguredTargets() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.skillsync", directoryHint: .isDirectory),
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
          path = "/Users/blob/.codex/skills"
          source = "tool"
          """.utf8
        ),
        atPath: "/Users/blob/.skillsync/config.toml"
      )

      try await assertCommand(
        ["sync"],
        stdout: {
          """
          [ok]   codex   /Users/blob/.codex/skills   (0 skills)
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
    func printsResolvedPathAndConfiguredPathWhenDifferent() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.skillsync", directoryHint: .isDirectory),
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
        ["sync"],
        stdout: {
          """
          [ok]   codex   /Users/blob/.codex/skills   (0 skills)
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
    func noTargetsConfiguredThrowsActionableError() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      await assertCommandThrows(
        ["sync"],
        error: {
          """
          No targets configured. Use `skillsync target add ...`.
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
    func outputsJSON() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.skillsync", directoryHint: .isDirectory),
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

      let output = try await commandOutput(
        ["sync", "--json"],
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
        }
      )
      let json = try #require(
        JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
      )
      let targets = try #require(json["targets"] as? [[String: Any]])
      #expect(targets.count == 1)
      let first = try #require(targets.first)
      #expect(first["status"] as? String == "ok")
      #expect(first["syncedSkills"] as? Int == 0)
      let target = try #require(first["target"] as? [String: Any])
      #expect(target["id"] as? String == "codex")
      #expect(target["path"] as? String == "~/.codex/skills")
      #expect(target["source"] as? String == "tool")
    }

    @Test
    func printsPushTipWhenUpstreamConfiguredAndDirty() async throws {
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
        ["sync"],
        stdout: {
          """
          [ok]   codex   /Users/blob/.codex/skills   (0 skills)
          Tip: local skillsync changes are not on remote yet. Run: skillsync push
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
              if arguments == ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"] {
                return .init(exitCode: 0, stdout: "origin/main\n", stderr: "")
              }
              if arguments == ["status", "--porcelain"] {
                return .init(exitCode: 0, stdout: " M skills/pdf/SKILL.md\n", stderr: "")
              }
              if arguments == ["rev-list", "--count", "@{u}..HEAD"] {
                return .init(exitCode: 0, stdout: "0\n", stderr: "")
              }
              return .init(exitCode: 1, stdout: "", stderr: "unexpected")
            }
          )
        }
      )
    }

    @Test
    func doesNotPrintPushTipWhenNoUpstream() async throws {
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
        ["sync"],
        stdout: {
          """
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
              if arguments == ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"] {
                return .init(exitCode: 1, stdout: "", stderr: "no upstream")
              }
              return .init(exitCode: 1, stdout: "", stderr: "unexpected")
            }
          )
        }
      )
    }

    @Test
    func jsonOutputDoesNotRunPushNudgeChecks() async throws {
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

      let gitCommandCount = LockIsolated(0)
      let output = try await commandOutput(
        ["sync", "--json"],
        dependencies: {
          $0.pathClient = PathClient(
            homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
            currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
          )
          $0.fileSystemClient = fileSystem.client
          $0.gitClient = GitClient(
            run: { _, _ in
              gitCommandCount.withValue { $0 += 1 }
              return .init(exitCode: 0, stdout: "", stderr: "")
            }
          )
        }
      )

      #expect(gitCommandCount.value == 0)
      let json = try #require(
        JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
      )
      let targets = try #require(json["targets"] as? [[String: Any]])
      #expect(targets.count == 1)
    }
  }
}
