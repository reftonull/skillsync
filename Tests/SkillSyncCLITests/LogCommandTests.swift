import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct LogCommandTests {
    @Test
    func throwsWhenSkillMissing() async {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      await assertCommandThrows(
        ["log", "missing"],
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

    @Test
    func printsNoLinesForSkillWithNoObservations() async throws {
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
        ["log", "pdf"],
        stdout: { "" },
        dependencies: deps
      )
    }

    @Test
    func printsSummaryForSkillWithNoObservations() async throws {
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
        ["log", "pdf", "--summary"],
        stdout: {
          """
          pdf: 0 invocations
          """
        },
        dependencies: deps
      )
    }

    @Test
    func printsHistoryAndSummary() async throws {
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

      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/.skillsync/logs", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )
      try fileSystem.write(
        Data(
          """
          {"ts":"2026-02-07T10:15:00Z","signal":"positive","version":3,"note":"Handled encrypted input well"}
          {"ts":"2026-02-07T11:30:00Z","signal":"negative","version":3,"note":"Failed on multi-page PDF"}
          {"ts":"2026-02-07T12:00:00Z","signal":"positive","version":3}
          """.utf8
        ),
        to: URL(filePath: "/Users/blob/.skillsync/logs/pdf.jsonl")
      )

      try await assertCommand(
        ["log", "pdf"],
        stdout: {
          """
          2026-02-07T10:15:00Z  positive  "Handled encrypted input well"
          2026-02-07T11:30:00Z  negative  "Failed on multi-page PDF"
          2026-02-07T12:00:00Z  positive
          """
        },
        dependencies: deps
      )

      try await assertCommand(
        ["log", "pdf", "--summary"],
        stdout: {
          """
          pdf: 3 invocations, 2 positive, 1 negative (33% negative)
          """
        },
        dependencies: deps
      )
    }
  }
}
