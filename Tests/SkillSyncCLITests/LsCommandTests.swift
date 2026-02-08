import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct LsCommandTests {
    @Test
    func printsNoSkillsWhenEmpty() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      try await assertCommand(
        ["ls"],
        stdout: {
          """
          No skills found.
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
    func printsSkillsWithStateAndStats() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      let deps: (inout DependencyValues) throws -> Void = {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
      }

      try await assertCommand(
        ["new", "shell"],
        stdout: {
          """
          Created skill shell at /Users/blob/.skillsync/skills/shell
          """
        },
        dependencies: deps
      )
      try await assertCommand(
        ["new", "pdf"],
        stdout: {
          """
          Created skill pdf at /Users/blob/.skillsync/skills/pdf
          """
        },
        dependencies: deps
      )
      try await assertCommand(
        ["rm", "shell"],
        stdout: {
          """
          Marked skill shell for removal (pending prune on next sync)
          """
        },
        dependencies: deps
      )

      try await assertCommand(
        ["ls"],
        stdout: {
          """
          NAME    STATE            OBSERVATIONS
          pdf     active           0
          shell   pending_remove   0
          """
        },
        dependencies: deps
      )
    }

    @Test
    func outputsJSON() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      let deps: (inout DependencyValues) throws -> Void = {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
      }

      try await assertCommand(
        ["new", "pdf"],
        stdout: {
          """
          Created skill pdf at /Users/blob/.skillsync/skills/pdf
          """
        },
        dependencies: deps
      )

      let output = try await commandOutput(
        ["ls", "--json"],
        dependencies: deps
      )
      let json = try #require(
        JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
      )
      let skills = try #require(json["skills"] as? [[String: Any]])
      #expect(skills.count == 1)
      #expect(skills[0]["name"] as? String == "pdf")
      #expect(skills[0]["state"] as? String == "active")
      #expect(skills[0]["totalInvocations"] as? Int == 0)
      #expect(skills[0]["positive"] as? Int == 0)
      #expect(skills[0]["negative"] as? Int == 0)
    }
  }
}
