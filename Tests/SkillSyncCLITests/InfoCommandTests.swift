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
          pdf
            version: 1
            state: active
            content-hash: sha256:a1b2c3
            created: 2025-02-06T00:00:00Z
            source: hand-authored
            invocations: 0 (positive: 0, negative: 0)
          """
        },
        dependencies: deps
      )
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
