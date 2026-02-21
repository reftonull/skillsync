import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct CopyDirectoryFeatureTests {
  @Test
  func copiesFilesAndSubdirectoriesRecursively() throws {
    let fileSystem = InMemoryFileSystem()

    try fileSystem.createDirectory(
      at: URL(filePath: "/src/skill/scripts", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(Data("# Skill\n".utf8), to: URL(filePath: "/src/skill/SKILL.md"))
    try fileSystem.write(Data("echo hi\n".utf8), to: URL(filePath: "/src/skill/scripts/run.sh"))
    try fileSystem.createDirectory(
      at: URL(filePath: "/dst", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try CopyDirectoryFeature().run(
        from: URL(filePath: "/src/skill", directoryHint: .isDirectory),
        to: URL(filePath: "/dst/skill", directoryHint: .isDirectory)
      )
    }

    #expect(fileSystem.client.fileExists("/dst/skill/SKILL.md"))
    #expect(fileSystem.client.fileExists("/dst/skill/scripts/run.sh"))
    #expect(try fileSystem.data(at: URL(filePath: "/dst/skill/SKILL.md")) == Data("# Skill\n".utf8))
    #expect(try fileSystem.data(at: URL(filePath: "/dst/skill/scripts/run.sh")) == Data("echo hi\n".utf8))
  }

  @Test
  func excludesNamedFiles() throws {
    let fileSystem = InMemoryFileSystem()

    try fileSystem.createDirectory(
      at: URL(filePath: "/src/skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(Data("# Skill\n".utf8), to: URL(filePath: "/src/skill/SKILL.md"))
    try fileSystem.write(Data("meta\n".utf8), to: URL(filePath: "/src/skill/.meta.toml"))
    try fileSystem.createDirectory(
      at: URL(filePath: "/dst", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try CopyDirectoryFeature().run(
        from: URL(filePath: "/src/skill", directoryHint: .isDirectory),
        to: URL(filePath: "/dst/skill", directoryHint: .isDirectory),
        excluding: [".meta.toml"]
      )
    }

    #expect(fileSystem.client.fileExists("/dst/skill/SKILL.md"))
    #expect(!fileSystem.client.fileExists("/dst/skill/.meta.toml"))
  }

  @Test
  func excludesNamedSubdirectory() throws {
    let fileSystem = InMemoryFileSystem()

    try fileSystem.createDirectory(
      at: URL(filePath: "/src/skill/.git", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(Data("# Skill\n".utf8), to: URL(filePath: "/src/skill/SKILL.md"))
    try fileSystem.write(Data("git stuff\n".utf8), to: URL(filePath: "/src/skill/.git/HEAD"))
    try fileSystem.createDirectory(
      at: URL(filePath: "/dst", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try CopyDirectoryFeature().run(
        from: URL(filePath: "/src/skill", directoryHint: .isDirectory),
        to: URL(filePath: "/dst/skill", directoryHint: .isDirectory),
        excluding: [".git"]
      )
    }

    #expect(fileSystem.client.fileExists("/dst/skill/SKILL.md"))
    #expect(!fileSystem.client.fileExists("/dst/skill/.git"))
    #expect(!fileSystem.client.fileExists("/dst/skill/.git/HEAD"))
  }

  @Test
  func copiesEmptySourceDirectory() throws {
    let fileSystem = InMemoryFileSystem()

    try fileSystem.createDirectory(
      at: URL(filePath: "/src/empty", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/dst", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try CopyDirectoryFeature().run(
        from: URL(filePath: "/src/empty", directoryHint: .isDirectory),
        to: URL(filePath: "/dst/empty", directoryHint: .isDirectory)
      )
    }

    #expect(fileSystem.client.isDirectory("/dst/empty"))
  }

  @Test
  func sortsCopiedChildrenDeterministically() throws {
    let fileSystem = InMemoryFileSystem()

    try fileSystem.createDirectory(
      at: URL(filePath: "/src/skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(Data("z\n".utf8), to: URL(filePath: "/src/skill/z.md"))
    try fileSystem.write(Data("a\n".utf8), to: URL(filePath: "/src/skill/a.md"))
    try fileSystem.write(Data("m\n".utf8), to: URL(filePath: "/src/skill/m.md"))
    try fileSystem.createDirectory(
      at: URL(filePath: "/dst", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try CopyDirectoryFeature().run(
        from: URL(filePath: "/src/skill", directoryHint: .isDirectory),
        to: URL(filePath: "/dst/skill", directoryHint: .isDirectory)
      )
    }

    #expect(fileSystem.client.fileExists("/dst/skill/a.md"))
    #expect(fileSystem.client.fileExists("/dst/skill/m.md"))
    #expect(fileSystem.client.fileExists("/dst/skill/z.md"))
  }
}
