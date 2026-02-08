import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct TargetCommandTests {
    @Test
    func listShowsEmptyMessage() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      try await assertCommand(
        ["target", "list"],
        stdout: {
          """
          No targets configured.
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
    func addToolThenList() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      let deps: (inout DependencyValues) throws -> Void = {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      }

      try await assertCommand(
        ["target", "add", "--tool", "codex"],
        stdout: {
          """
          added target=codex path=~/.codex/skills
          """
        },
        dependencies: deps
      )

      try await assertCommand(
        ["target", "list"],
        stdout: {
          """
          ID      PATH
          codex   ~/.codex/skills
          """
        },
        dependencies: deps
      )
    }

    @Test
    func addPathAndRemove() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      let deps: (inout DependencyValues) throws -> Void = {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      }

      try await assertCommand(
        ["target", "add", "--path", "/tmp/custom"],
        stdout: {
          """
          added target=path-1 path=/tmp/custom
          """
        },
        dependencies: deps
      )

      try await assertCommand(
        ["target", "remove", "path-1"],
        stdout: {
          """
          removed target=path-1 path=/tmp/custom
          """
        },
        dependencies: deps
      )
    }

    @Test
    func listOutputsJSON() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )
      let deps: (inout DependencyValues) throws -> Void = {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      }

      try await assertCommand(
        ["target", "add", "--tool", "codex"],
        stdout: {
          """
          added target=codex path=~/.codex/skills
          """
        },
        dependencies: deps
      )

      let output = try await commandOutput(
        ["target", "list", "--json"],
        dependencies: deps
      )
      let json = try #require(
        JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]]
      )
      #expect(json.count == 1)
      #expect(json[0]["id"] as? String == "codex")
      #expect(json[0]["path"] as? String == "~/.codex/skills")
      #expect(json[0]["source"] as? String == "tool")
    }

    @Test
    func unknownToolThrowsActionableError() async {
      let fileSystem = InMemoryFileSystem()
      await assertCommandThrows(
        ["target", "add", "--tool", "unknown"],
        error: {
          """
          Unknown tool 'unknown'. Known tools: claude-code, codex, cursor.
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
