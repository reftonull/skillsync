import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct CommitFeatureTests {
  @Test
  func commitsEditingChangesAndUpdatesMeta() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    let created = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try NewFeature().run(
        .init(name: "pdf", description: "Original")
      )
    }

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/skills/pdf/scripts", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("legacy\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/skills/pdf/scripts/legacy.txt")
    )

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_001)
    } operation: {
      try EditFeature().run(.init(name: "pdf", reset: true))
    }

    try fileSystem.write(
      Data("# pdf\n\nCommitted\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/editing/pdf/SKILL.md")
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/editing/pdf/scripts", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("print(\"ok\")\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/editing/pdf/scripts/new.py")
    )
    try fileSystem.removeItem(at: URL(filePath: "/Users/blob/.skillsync/editing/pdf/scripts/legacy.txt"))

    let committed = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_002)
    } operation: {
      try CommitFeature().run(.init(name: "pdf", reason: "Refine wording"))
    }

    #expect(committed.contentHash != created.contentHash)
    #expect(committed.versionAfter == 2)
    #expect(!fileSystem.client.fileExists("/Users/blob/.skillsync/locks/pdf.lock"))
    #expect(!fileSystem.client.fileExists("/Users/blob/.skillsync/editing/pdf"))
    #expect(!fileSystem.client.fileExists("/Users/blob/.skillsync/skills/pdf/scripts/legacy.txt"))
    #expect(fileSystem.client.fileExists("/Users/blob/.skillsync/skills/pdf/scripts/new.py"))
    let skillMarkdown = try fileSystem.data(at: URL(filePath: "/Users/blob/.skillsync/skills/pdf/SKILL.md"))
    #expect(String(decoding: skillMarkdown, as: UTF8.self).contains("Committed"))
    let meta = try fileSystem.data(at: URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml"))
    let metaContents = String(decoding: meta, as: UTF8.self)
    #expect(metaContents.contains("version = 2"))
    #expect(metaContents.contains("content-hash = \"\(committed.contentHash)\""))
  }

  @Test
  func throwsWhenLockMissing() {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    #expect(throws: CommitFeature.Error.lockNotHeld(name: "pdf", lockFile: "/Users/blob/.skillsync/locks/pdf.lock")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try CommitFeature().run(.init(name: "pdf", reason: "Test"))
      }
    }
  }

  @Test
  func throwsWhenEditingContainsReservedMeta() throws {
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
        .init(name: "pdf", description: "Original")
      )
    }

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_001)
    } operation: {
      try EditFeature().run(.init(name: "pdf", reset: false))
    }

    try fileSystem.write(
      Data("[skill]\nversion = 100\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/editing/pdf/.meta.toml")
    )

    #expect(throws: CommitFeature.Error.reservedPath(".meta.toml")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try CommitFeature().run(.init(name: "pdf", reason: "Test"))
      }
    }
  }
}
