import ConcurrencyExtras
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct GitHubSkillClientTests {
  @Test
  func fetchRejectsSymbolicLinksInSkillTree() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let source = try GitHubSkillSource(repo: "acme/skills", skillPath: "skills/review-assistant", ref: "main")
    let commands = LockIsolated<[[String]]>([])

    #expect(throws: GitHubSkillClient.Error.symbolicLinkNotAllowed("external-link")) {
      try withDependencies {
        $0.fileSystemClient = fileSystem.client
        $0.gitClient = GitClient(
          run: { workingDirectory, arguments in
            commands.withValue { $0.append(arguments) }

            if arguments == ["checkout", "FETCH_HEAD"] {
              let skillRoot = workingDirectory.appendingPathComponent(source.skillPath, isDirectory: true)
              try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
              try fileSystem.write(Data("# review-assistant\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))
              try fileSystem.createSymbolicLink(
                at: skillRoot.appendingPathComponent("external-link"),
                destination: URL(filePath: "/etc/hosts")
              )
            }

            if arguments == ["rev-parse", "HEAD"] {
              return .init(exitCode: 0, stdout: "abc123\n", stderr: "")
            }
            return .init(exitCode: 0, stdout: "", stderr: "")
          }
        )
      } operation: {
        _ = try GitHubSkillClient.live.fetch(source)
      }
    }

    #expect(
      commands.value == [
        ["init"],
        ["remote", "add", "origin", "https://github.com/acme/skills.git"],
        ["sparse-checkout", "init", "--cone"],
        ["sparse-checkout", "set", "skills/review-assistant"],
        ["fetch", "--depth", "1", "origin", "main"],
        ["checkout", "FETCH_HEAD"],
        ["rev-parse", "HEAD"],
      ]
    )
  }

  @Test
  func fetchReturnsFilesForRegularSkillTree() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let source = try GitHubSkillSource(repo: "acme/skills", skillPath: "skills/review-assistant", ref: "main")

    let result = try withDependencies {
      $0.fileSystemClient = fileSystem.client
      $0.gitClient = GitClient(
        run: { workingDirectory, arguments in
          if arguments == ["checkout", "FETCH_HEAD"] {
            let skillRoot = workingDirectory.appendingPathComponent(source.skillPath, isDirectory: true)
            try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
            try fileSystem.write(Data("# review-assistant\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))
            let scriptsDirectory = skillRoot.appendingPathComponent("scripts", isDirectory: true)
            try fileSystem.createDirectory(at: scriptsDirectory, withIntermediateDirectories: true)
            try fileSystem.write(Data("echo hi\n".utf8), to: scriptsDirectory.appendingPathComponent("run.sh"))
          }

          if arguments == ["rev-parse", "HEAD"] {
            return .init(exitCode: 0, stdout: "abc123\n", stderr: "")
          }
          return .init(exitCode: 0, stdout: "", stderr: "")
        }
      )
    } operation: {
      try GitHubSkillClient.live.fetch(source)
    }

    #expect(result.commit == "abc123")
    #expect(result.resolvedRef == "main")
    #expect(result.files["SKILL.md"] == Data("# review-assistant\n".utf8))
    #expect(result.files["scripts/run.sh"] == Data("echo hi\n".utf8))
  }
}
