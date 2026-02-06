import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct WriteFeatureTests {
  @Test
  func writesFileAndUpdatesContentHash() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    let skill = try withDependencies {
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
      at: URL(filePath: "/Users/blob/project/tmp", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("print(\"hello\")\n".utf8),
      to: URL(filePath: "/Users/blob/project/tmp/extract.py")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try WriteFeature().run(
        .init(
          skillName: "pdf",
          destinationRelativePath: "scripts/extract.py",
          sourcePath: "tmp/extract.py"
        )
      )
    }

    #expect(result.contentHash != skill.contentHash)

    let written = try fileSystem.data(
      at: URL(filePath: "/Users/blob/.skillsync/skills/pdf/scripts/extract.py")
    )
    expectNoDifference(String(decoding: written, as: UTF8.self), "print(\"hello\")\n")

    let meta = try fileSystem.data(at: URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml"))
    #expect(String(decoding: meta, as: UTF8.self).contains("content-hash = \"\(result.contentHash)\""))
  }

  @Test
  func rejectsAbsoluteDestinationPath() {
    let fileSystem = InMemoryFileSystem()

    #expect(throws: WriteFeature.Error.invalidDestinationPath("/tmp/file.txt")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try WriteFeature().run(
          .init(
            skillName: "pdf",
            destinationRelativePath: "/tmp/file.txt",
            sourcePath: "tmp/source.txt"
          )
        )
      }
    }
  }

  @Test
  func rejectsDotDotTraversal() {
    let fileSystem = InMemoryFileSystem()

    #expect(throws: WriteFeature.Error.invalidDestinationPath("../file.txt")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try WriteFeature().run(
          .init(
            skillName: "pdf",
            destinationRelativePath: "../file.txt",
            sourcePath: "tmp/source.txt"
          )
        )
      }
    }
  }

  @Test
  func rejectsReservedMetaPath() {
    let fileSystem = InMemoryFileSystem()

    #expect(throws: WriteFeature.Error.reservedPath(".meta.toml")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try WriteFeature().run(
          .init(
            skillName: "pdf",
            destinationRelativePath: ".meta.toml",
            sourcePath: "tmp/source.txt"
          )
        )
      }
    }
  }
}
