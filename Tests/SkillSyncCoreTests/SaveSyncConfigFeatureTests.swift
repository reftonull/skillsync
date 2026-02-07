import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct SaveSyncConfigFeatureTests {
  @Test
  func writesCanonicalConfigWithTargets() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SaveSyncConfigFeature().run(
        .init(
          targets: [
            .init(id: "codex", path: "~/.codex/skills", source: .tool),
            .init(id: "project-codex", path: "/Users/blob/work/.codex/skills", source: .project),
          ],
          observation: .init(mode: .remind, threshold: 0.5, minInvocations: 7)
        )
      )
    }

    let config = try String(
      decoding: fileSystem.data(
        at: URL(filePath: "/Users/blob/.skillsync/config.toml")
      ),
      as: UTF8.self
    )
    expectNoDifference(
      config,
      """
      [skillsync]
      version = "1"

      [observation]
      mode = "remind"
      threshold = 0.5
      min_invocations = 7

      [[targets]]
      id = "codex"
      path = "~/.codex/skills"
      source = "tool"

      [[targets]]
      id = "project-codex"
      path = "/Users/blob/work/.codex/skills"
      source = "project"
      """
    )
  }
}
