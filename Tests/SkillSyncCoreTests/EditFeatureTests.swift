import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct EditFeatureTests {
  @Test
  func preparesEditingCopyAndAcquiresLock() throws {
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

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/skills/pdf/scripts", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("print(\"hello\")\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/skills/pdf/scripts/extract.py")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try EditFeature().run(.init(name: "pdf", reset: false))
    }

    #expect(result.editRoot.path == "/Users/blob/.skillsync/editing/pdf")
    #expect(result.lockFile.path == "/Users/blob/.skillsync/locks/pdf.lock")

    #expect(fileSystem.client.fileExists("/Users/blob/.skillsync/editing/pdf/SKILL.md"))
    #expect(fileSystem.client.fileExists("/Users/blob/.skillsync/editing/pdf/scripts/extract.py"))
    #expect(!fileSystem.client.fileExists("/Users/blob/.skillsync/editing/pdf/.meta.toml"))
    #expect(fileSystem.client.fileExists("/Users/blob/.skillsync/locks/pdf.lock"))
  }

  @Test
  func resetRecopiesCanonicalIntoEditing() throws {
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

    try fileSystem.removeItem(at: URL(filePath: "/Users/blob/.skillsync/locks/pdf.lock"))
    try fileSystem.write(
      Data("# pdf\n\nReset canonical\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/skills/pdf/SKILL.md")
    )

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_002)
    } operation: {
      try EditFeature().run(.init(name: "pdf", reset: true))
    }

    let editingSkill = try fileSystem.data(
      at: URL(filePath: "/Users/blob/.skillsync/editing/pdf/SKILL.md")
    )
    #expect(String(decoding: editingSkill, as: UTF8.self).contains("Reset canonical"))
  }

  @Test
  func throwsWhenSkillMissing() {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    #expect(throws: EditFeature.Error.skillNotFound("missing")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try EditFeature().run(.init(name: "missing", reset: false))
      }
    }
  }

  @Test
  func throwsWhenSkillLockAlreadyExists() throws {
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

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/locks", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("owner = \"another-agent\"\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/locks/pdf.lock")
    )

    #expect(throws: EditFeature.Error.lockAlreadyHeld(name: "pdf", lockFile: "/Users/blob/.skillsync/locks/pdf.lock")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
      } operation: {
        try EditFeature().run(.init(name: "pdf", reset: false))
      }
    }
  }
}
