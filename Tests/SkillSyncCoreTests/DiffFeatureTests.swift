import CustomDump
import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct DiffFeatureTests {
  @Test
  func throwsWhenSkillMissing() {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    #expect(throws: DiffFeature.Error.skillNotFound("missing")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try DiffFeature().run(.init(name: "missing"))
      }
    }
  }

  @Test
  func throwsWhenEditCopyMissing() throws {
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
      try NewFeature().run(.init(name: "pdf", description: "Original"))
    }

    #expect(throws: DiffFeature.Error.editCopyNotFound("pdf")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try DiffFeature().run(.init(name: "pdf"))
      }
    }
  }

  @Test
  func reportsAddedModifiedAndDeletedChangesDeterministically() throws {
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
      try NewFeature().run(.init(name: "pdf", description: "Original"))
    }

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/skills/pdf/scripts", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("echo legacy\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/skills/pdf/scripts/legacy.sh")
    )

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_001)
    } operation: {
      try EditFeature().run(.init(name: "pdf", force: false))
    }

    try fileSystem.write(
      Data("# pdf\n\nChanged\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/editing/pdf/SKILL.md")
    )
    try fileSystem.removeItem(
      at: URL(filePath: "/Users/blob/.skillsync/editing/pdf/scripts/legacy.sh")
    )
    try fileSystem.write(
      Data("echo new\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/editing/pdf/scripts/new.sh")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try DiffFeature().run(.init(name: "pdf"))
    }

    #expect(result.skill == "pdf")
    #expect(result.summary == .init(added: 1, modified: 1, deleted: 1))
    #expect(result.changes.map(\.path) == ["SKILL.md", "scripts/legacy.sh", "scripts/new.sh"])
    #expect(result.changes.map(\.status) == [.modified, .deleted, .added])
    #expect(result.changes.map(\.kind) == [.text, .text, .text])
    #expect(result.changes[0].patch == diff("# pdf\n\nOriginal", "# pdf\n\nChanged\n"))
    #expect(result.changes[1].patch == "echo legacy\n")
    #expect(result.changes[2].patch == "echo new\n")
  }

  @Test
  func marksBinaryFilesWithByteCounts() throws {
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
      try NewFeature().run(.init(name: "pdf", description: "Original"))
    }

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_001)
    } operation: {
      try EditFeature().run(.init(name: "pdf", force: false))
    }

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/editing/pdf/assets", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data([0xFF, 0x00, 0xFE]),
      to: URL(filePath: "/Users/blob/.skillsync/editing/pdf/assets/blob.bin")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try DiffFeature().run(.init(name: "pdf"))
    }

    #expect(result.summary.added == 1)
    #expect(result.changes.count == 1)
    #expect(result.changes[0].path == "assets/blob.bin")
    #expect(result.changes[0].kind == .binary)
    #expect(result.changes[0].patch == "binary file added (3 bytes)")
  }
}
