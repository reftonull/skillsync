import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct ObserveFeatureTests {
  private struct ObservationRecord: Decodable, Equatable {
    var ts: String
    var signal: String
    var version: Int
    var note: String?
  }

  @Test
  func throwsWhenSkillMissing() {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    #expect(throws: ObserveFeature.Error.skillNotFound("pdf")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try ObserveFeature().run(
          .init(name: "pdf", signal: .positive, note: nil)
        )
      }
    }
  }

  @Test
  func appendsJsonlRecordWithTimestampSignalVersionAndNote() throws {
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

    let metaURL = URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().run(
        metaURL: metaURL,
        updates: [
          .init(section: "skill", key: "version", operation: .setInt(3))
        ]
      )
    }

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_060)
    } operation: {
      try ObserveFeature().run(
        .init(
          name: "pdf",
          signal: .positive,
          note: "Handled encrypted input well"
        )
      )
    }

    expectNoDifference(result.version, 3)
    expectNoDifference(result.ts, "2025-02-06T00:01:00Z")

    let logURL = URL(filePath: "/Users/blob/.skillsync/logs/pdf.jsonl")
    let lines = try fileSystem
      .data(at: logURL)
      .split(separator: UInt8(ascii: "\n"))
      .map { String(decoding: $0, as: UTF8.self) }
    expectNoDifference(lines.count, 1)

    let record = try JSONDecoder().decode(ObservationRecord.self, from: Data(lines[0].utf8))
    expectNoDifference(
      record,
      .init(
        ts: "2025-02-06T00:01:00Z",
        signal: "positive",
        version: 3,
        note: "Handled encrypted input well"
      )
    )

    let meta = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: metaURL)
    }
    expectNoDifference(meta.int(section: "stats", key: "total-invocations"), 1)
    expectNoDifference(meta.int(section: "stats", key: "positive"), 1)
    expectNoDifference(meta.int(section: "stats", key: "negative"), 0)
  }

  @Test
  func appendsMultipleRecordsAndTracksPositiveAndNegativeCounters() throws {
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

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_060)
    } operation: {
      try ObserveFeature().run(
        .init(name: "pdf", signal: .positive, note: nil)
      )
    }

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_120)
    } operation: {
      try ObserveFeature().run(
        .init(name: "pdf", signal: .negative, note: "Failed on multi-page PDF"))
    }

    let logURL = URL(filePath: "/Users/blob/.skillsync/logs/pdf.jsonl")
    let lines = try fileSystem
      .data(at: logURL)
      .split(separator: UInt8(ascii: "\n"))
      .map { String(decoding: $0, as: UTF8.self) }
    expectNoDifference(lines.count, 2)

    let records = try lines.map { try JSONDecoder().decode(ObservationRecord.self, from: Data($0.utf8)) }
    expectNoDifference(records[0].ts, "2025-02-06T00:01:00Z")
    expectNoDifference(records[0].signal, "positive")
    expectNoDifference(records[0].note, nil)
    expectNoDifference(records[1].ts, "2025-02-06T00:02:00Z")
    expectNoDifference(records[1].signal, "negative")
    expectNoDifference(records[1].note, "Failed on multi-page PDF")

    let metaURL = URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
    let meta = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: metaURL)
    }
    expectNoDifference(meta.int(section: "stats", key: "total-invocations"), 2)
    expectNoDifference(meta.int(section: "stats", key: "positive"), 1)
    expectNoDifference(meta.int(section: "stats", key: "negative"), 1)
  }
}
