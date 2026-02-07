import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct AbortFeatureTests {
  @Test
  func removesEditCopyAndLock() throws {
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
      try EditFeature().run(.init(name: "pdf", force: false))
    }

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try AbortFeature().run(.init(name: "pdf"))
    }

    #expect(result.name == "pdf")
    #expect(result.removedEditCopy)
    #expect(!fileSystem.client.fileExists("/Users/blob/.skillsync/locks/pdf.lock"))
    #expect(!fileSystem.client.fileExists("/Users/blob/.skillsync/editing/pdf"))
  }

  @Test
  func throwsWhenLockMissing() {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    #expect(throws: AbortFeature.Error.noActiveEdit(name: "pdf")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try AbortFeature().run(.init(name: "pdf"))
      }
    }
  }
}
