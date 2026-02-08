import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct InfoCommandTests {
    @Test
    func printsSkillMetadata() async throws {
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

      let metaURL = URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
      try withDependencies {
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try UpdateMetaFeature().run(
          metaURL: metaURL,
          updates: [
            .init(section: "skill", key: "content-hash", operation: .setString("sha256:a1b2c3"))
          ]
        )
      }

      try await assertCommand(
        ["info", "pdf"],
        stdout: {
          """
          Skill:        pdf
          Path:         /Users/blob/.skillsync/skills/pdf
          Version:      1
          State:        active
          Source:       user
          Created:      2025-02-06T00:00:00Z
          Content hash: sha256:a1b2c3
          Observations: 0 (0 positive, 0 negative)
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
        ["info", "pdf", "--json"],
        dependencies: deps
      )
      let json = try #require(
        JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any]
      )
      #expect(json["name"] as? String == "pdf")
      #expect(json["path"] as? String == "/Users/blob/.skillsync/skills/pdf")
      #expect(json["version"] as? Int == 1)
      #expect(json["state"] as? String == "active")
      #expect(json["source"] as? String == "hand-authored")
      #expect(json["totalInvocations"] as? Int == 0)
      #expect(json["positive"] as? Int == 0)
      #expect(json["negative"] as? Int == 0)
    }

    @Test
    func throwsWhenSkillMissing() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      await assertCommandThrows(
        ["info", "missing"],
        error: {
          """
          Skill 'missing' not found.
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
