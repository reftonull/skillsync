import Dependencies
import Foundation
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

extension BaseSuite {
  @Suite
  struct WriteCommandTests {
    @Test
    func writesSkillFileFromSourcePath() async throws {
      let fileSystem = InMemoryFileSystem(
        homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
      )

      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/project/tmp", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )
      try fileSystem.write(
        Data("echo hello\n".utf8),
        to: URL(filePath: "/Users/blob/project/tmp/run.sh")
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
        ["write", "shell", "--file", "scripts/run.sh", "--from", "tmp/run.sh"],
        stdout: {
          """
          Updated skill shell file scripts/run.sh
          """
        },
        dependencies: deps
      )
    }

    @Test
    func rejectsReservedPath() async throws {
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

      try fileSystem.createDirectory(
        at: URL(filePath: "/Users/blob/project/tmp", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )
      try fileSystem.write(
        Data("body".utf8),
        to: URL(filePath: "/Users/blob/project/tmp/body.txt")
      )

      try await assertCommand(
        ["new", "shell"],
        stdout: {
          """
          Created skill shell at /Users/blob/.skillsync/skills/shell
          """
        },
        dependencies: deps
      )

      await assertCommandThrows(
        ["write", "shell", "--file", ".meta.toml", "--from", "tmp/body.txt"],
        error: {
          """
          Destination path '.meta.toml' is reserved.
          """
        },
        dependencies: deps
      )
    }
  }
}
