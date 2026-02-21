import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct RmFeatureTests {
  @Test
  func marksSkillAsPendingRemoveWithoutDeletingFiles() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try NewFeature().run(
        .init(name: "pdf", description: "Extract and summarize PDF text.")
      )
    }

    let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/pdf", directoryHint: .isDirectory)
    let skillMarkdownPath = skillRoot.appendingPathComponent("SKILL.md")
    #expect(fileSystem.client.fileExists(skillMarkdownPath.path))

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try RmFeature().run(.init(name: "pdf"))
    }

    expectNoDifference(result.skillName, "pdf")
    #expect(fileSystem.client.fileExists(skillMarkdownPath.path))

    let meta = try fileSystem.data(at: skillRoot.appendingPathComponent(".meta.toml"))
    #expect(String(decoding: meta, as: UTF8.self).contains("state = \"pending_remove\""))
  }

  @Test
  func throwsWhenSkillDoesNotExist() {
    let fileSystem = InMemoryFileSystem()

    #expect(throws: RmFeature.Error.skillNotFound("missing")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try RmFeature().run(.init(name: "missing"))
      }
    }
  }

  @Test
  func throwsWhenMetaTomlIsMissing() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    // Create the skill directory without a .meta.toml file
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/skills/pdf", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("# PDF skill\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/skills/pdf/SKILL.md")
    )

    #expect(throws: RmFeature.Error.metaNotFound("pdf")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try RmFeature().run(.init(name: "pdf"))
      }
    }
  }
}
