import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct ObserveCommandTests {
    @Test
    func logsObservationAndPrintsStatus() async throws {
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
        ["new", "pdf"],
        stdout: {
          """
          Created skill pdf at /Users/blob/.skillsync/skills/pdf
          """
        },
        dependencies: {
          try deps(&$0)
          $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
        }
      )

      try await assertCommand(
        ["observe", "pdf", "--signal", "positive", "--note", "Handled encrypted input well"],
        stdout: {
          """
          Logged observation for pdf signal=positive
          """
        },
        dependencies: {
          try deps(&$0)
          $0.date.now = Date(timeIntervalSince1970: 1_738_800_060)
        }
      )

      let meta = try withDependencies {
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try UpdateMetaFeature().read(
          metaURL: URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
        )
      }
      #expect(meta.int(section: "stats", key: "total-invocations") == 1)
      #expect(meta.int(section: "stats", key: "positive") == 1)
      #expect(meta.int(section: "stats", key: "negative") == 0)
    }

    @Test
    func throwsWhenSkillMissing() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      await assertCommandThrows(
        ["observe", "missing", "--signal", "negative", "--note", "Failed"],
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
          $0.date.now = Date(timeIntervalSince1970: 1_738_800_060)
        }
      )
    }
  }
}
