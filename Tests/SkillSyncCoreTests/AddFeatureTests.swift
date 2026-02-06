import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct AddFeatureTests {
  @Test
  func importsSkillDirectoryAndCreatesMetaWhenMissing() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/existing-skill/scripts", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("# Existing Skill\n".utf8),
      to: URL(filePath: "/Users/blob/project/existing-skill/SKILL.md")
    )
    try fileSystem.write(
      Data("echo hi\n".utf8),
      to: URL(filePath: "/Users/blob/project/existing-skill/scripts/run.sh")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try AddFeature().run(.init(sourcePath: "existing-skill"))
    }

    expectNoDifference(result.skillName, "existing-skill")
    #expect(result.createdMeta)
    #expect(result.contentHash.hasPrefix("sha256:"))

    let destinationRoot = URL(filePath: "/Users/blob/.skillsync/skills/existing-skill", directoryHint: .isDirectory)
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent("SKILL.md").path))
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent("scripts/run.sh").path))
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent(".meta.toml").path))

    let meta = try fileSystem.data(at: destinationRoot.appendingPathComponent(".meta.toml"))
    let metaText = String(decoding: meta, as: UTF8.self)
    #expect(metaText.contains("source = \"imported\""))
    #expect(metaText.contains("content-hash = \"\(result.contentHash)\""))
  }

  @Test
  func rejectsSourceWithoutSkillMarkdown() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/no-skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    #expect(throws: AddFeature.Error.missingSkillMarkdown("/Users/blob/project/no-skill")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try AddFeature().run(.init(sourcePath: "no-skill"))
      }
    }
  }

  @Test
  func rejectsWhenDestinationSkillAlreadyExists() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/existing-skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("# Existing Skill\n".utf8),
      to: URL(filePath: "/Users/blob/project/existing-skill/SKILL.md")
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/skills/existing-skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    #expect(throws: AddFeature.Error.skillAlreadyExists("existing-skill")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try AddFeature().run(.init(sourcePath: "existing-skill"))
      }
    }
  }

  @Test
  func preservesExistingMetaAndRefreshesContentHash() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/existing-skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("# Existing Skill\n".utf8),
      to: URL(filePath: "/Users/blob/project/existing-skill/SKILL.md")
    )
    try fileSystem.write(
      Data(
        """
        [skill]
        source = "custom"
        content-hash = "sha256:old"
        """.utf8
      ),
      to: URL(filePath: "/Users/blob/project/existing-skill/.meta.toml")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try AddFeature().run(.init(sourcePath: "existing-skill"))
    }

    #expect(!result.createdMeta)
    let meta = try fileSystem.data(
      at: URL(filePath: "/Users/blob/.skillsync/skills/existing-skill/.meta.toml")
    )
    let metaText = String(decoding: meta, as: UTF8.self)
    #expect(metaText.contains("source = \"custom\""))
    #expect(metaText.contains("content-hash = \"\(result.contentHash)\""))
    #expect(!metaText.contains("sha256:old"))
  }
}
