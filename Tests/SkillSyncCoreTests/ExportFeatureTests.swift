import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct ExportFeatureTests {
  @Test
  func exportsSkillDirectoryRecursively() throws {
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
      Data("echo hi\n".utf8),
      to: URL(filePath: "/Users/blob/.skillsync/skills/pdf/scripts/run.sh")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try ExportFeature().run(
        .init(name: "pdf", destinationPath: "exports/pdf")
      )
    }

    expectNoDifference(result.skillName, "pdf")
    expectNoDifference(result.destination.path, "/Users/blob/project/exports/pdf")
    #expect(fileSystem.client.fileExists("/Users/blob/project/exports/pdf/SKILL.md"))
    #expect(!fileSystem.client.fileExists("/Users/blob/project/exports/pdf/.meta.toml"))
    #expect(fileSystem.client.fileExists("/Users/blob/project/exports/pdf/scripts/run.sh"))
  }

  @Test
  func throwsWhenSkillDoesNotExist() {
    let fileSystem = InMemoryFileSystem()

    #expect(throws: ExportFeature.Error.skillNotFound("missing")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try ExportFeature().run(
          .init(name: "missing", destinationPath: "exports/missing")
        )
      }
    }
  }

  @Test
  func throwsWhenDestinationAlreadyExists() throws {
    let fileSystem = InMemoryFileSystem()
    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try NewFeature().run(
        .init(name: "pdf", description: nil)
      )
    }

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/exports/pdf", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    #expect(throws: ExportFeature.Error.destinationAlreadyExists("/Users/blob/project/exports/pdf")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try ExportFeature().run(
          .init(name: "pdf", destinationPath: "exports/pdf")
        )
      }
    }
  }
}
