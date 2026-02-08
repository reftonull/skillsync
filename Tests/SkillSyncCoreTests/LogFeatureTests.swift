import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct LogFeatureTests {
  @Test
  func throwsWhenSkillMissing() {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    #expect(throws: LogFeature.Error.skillNotFound("pdf")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try LogFeature().run(.init(name: "pdf", summary: false))
      }
    }
  }

  @Test
  func returnsEmptyForMissingLogFile() throws {
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
      try NewFeature().run(.init(name: "pdf", description: nil))
    }

    let defaultResult = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LogFeature().run(.init(name: "pdf", summary: false))
    }

    let summaryResult = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LogFeature().run(.init(name: "pdf", summary: true))
    }

    expectNoDifference(defaultResult.lines, [])
    expectNoDifference(summaryResult.lines, ["pdf: 0 invocations"])
  }

  @Test
  func returnsEmptyForEmptyLogFile() throws {
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
      try NewFeature().run(.init(name: "pdf", description: nil))
    }

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/logs", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(Data(), to: URL(filePath: "/Users/blob/.skillsync/logs/pdf.jsonl"))

    let defaultResult = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LogFeature().run(.init(name: "pdf", summary: false))
    }

    let summaryResult = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LogFeature().run(.init(name: "pdf", summary: true))
    }

    expectNoDifference(defaultResult.lines, [])
    expectNoDifference(summaryResult.lines, ["pdf: 0 invocations"])
  }

  @Test
  func formatsMultipleObservationsInFileOrder() throws {
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
      try NewFeature().run(.init(name: "pdf", description: nil))
    }

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/logs", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data(
        """
        {"ts":"2026-02-07T10:15:00Z","signal":"positive","version":3,"note":"Handled encrypted input well"}
        {"ts":"2026-02-07T11:30:00Z","signal":"negative","version":3,"note":"Failed on multi-page PDF"}
        {"ts":"2026-02-07T12:00:00Z","signal":"positive","version":3}
        """.utf8
      ),
      to: URL(filePath: "/Users/blob/.skillsync/logs/pdf.jsonl")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LogFeature().run(.init(name: "pdf", summary: false))
    }

    expectNoDifference(
      result.records,
      [
        .init(
          timestamp: "2026-02-07T10:15:00Z",
          signal: .positive,
          note: "Handled encrypted input well",
          version: 3
        ),
        .init(
          timestamp: "2026-02-07T11:30:00Z",
          signal: .negative,
          note: "Failed on multi-page PDF",
          version: 3
        ),
        .init(
          timestamp: "2026-02-07T12:00:00Z",
          signal: .positive,
          note: nil,
          version: 3
        ),
      ]
    )
    expectNoDifference(result.lines, [])
  }

  @Test
  func computesSummaryFromHistoryWithRoundedPercentage() throws {
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
      try NewFeature().run(.init(name: "pdf", description: nil))
    }

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/logs", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data(
        """
        {"ts":"2026-02-07T10:15:00Z","signal":"positive","version":3}
        {"ts":"2026-02-07T11:30:00Z","signal":"negative","version":3}
        {"ts":"2026-02-07T12:00:00Z","signal":"positive","version":3}
        """.utf8
      ),
      to: URL(filePath: "/Users/blob/.skillsync/logs/pdf.jsonl")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LogFeature().run(.init(name: "pdf", summary: true))
    }

    expectNoDifference(result.lines, ["pdf: 3 invocations, 2 positive, 1 negative (33% negative)"])
  }
}
