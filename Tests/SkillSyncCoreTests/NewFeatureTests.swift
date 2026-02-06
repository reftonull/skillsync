import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct NewFeatureTests {
  @Test
  func createsSkillScaffoldAndMeta() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)  // 2025-02-11T04:00:00Z
    } operation: {
      try NewFeature().run(
        .init(name: "pdf", description: "Extract and summarize PDF text.")
      )
    }

    let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/pdf", directoryHint: .isDirectory)
    expectNoDifference(result.skillRoot, skillRoot)
    #expect(fileSystem.client.fileExists(skillRoot.appendingPathComponent("SKILL.md").path))
    #expect(fileSystem.client.fileExists(skillRoot.appendingPathComponent(".meta.toml").path))

    let skillMarkdown = try fileSystem.data(at: skillRoot.appendingPathComponent("SKILL.md"))
    expectNoDifference(
      String(decoding: skillMarkdown, as: UTF8.self),
      """
      # pdf

      Extract and summarize PDF text.
      """
    )

    let metaData = try fileSystem.data(at: skillRoot.appendingPathComponent(".meta.toml"))
    let meta = String(decoding: metaData, as: UTF8.self)
    #expect(meta.contains("source = \"hand-authored\""))
    #expect(meta.contains("version = 1"))
    #expect(meta.contains("state = \"active\""))
    #expect(meta.contains("content-hash = \"\(result.contentHash)\""))
    #expect(meta.contains("total-invocations = 0"))
    #expect(meta.contains("positive = 0"))
    #expect(meta.contains("negative = 0"))
  }

  @Test
  func rejectsInvalidName() {
    let fileSystem = InMemoryFileSystem()

    #expect(throws: NewFeature.Error.invalidName("PDF!")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try NewFeature().run(.init(name: "PDF!", description: nil))
      }
    }
  }

  @Test
  func rejectsIfSkillAlreadyExists() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/skills/pdf", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    #expect(throws: NewFeature.Error.skillAlreadyExists("pdf")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try NewFeature().run(.init(name: "pdf", description: nil))
      }
    }
  }
}
