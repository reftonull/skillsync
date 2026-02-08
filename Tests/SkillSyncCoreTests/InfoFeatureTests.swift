import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct InfoFeatureTests {
  @Test
  func throwsWhenSkillMissing() {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    #expect(throws: InfoFeature.Error.skillNotFound("pdf")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try InfoFeature().run(.init(name: "pdf"))
      }
    }
  }

  @Test
  func readsMetadataFromMetaToml() throws {
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
          .init(section: "skill", key: "version", operation: .setInt(3)),
          .init(section: "skill", key: "content-hash", operation: .setString("sha256:a1b2c3")),
        ]
      )
    }

    let logsDir = URL(filePath: "/Users/blob/.skillsync/logs", directoryHint: .isDirectory)
    try fileSystem.createDirectory(at: logsDir, withIntermediateDirectories: true)
    var jsonlLines: [String] = []
    for i in 0..<7 {
      jsonlLines.append(#"{"ts":"2025-02-06T00:0\#(i):00Z","signal":"positive","version":3}"#)
    }
    for i in 0..<5 {
      jsonlLines.append(#"{"ts":"2025-02-06T01:0\#(i):00Z","signal":"negative","version":3}"#)
    }
    let logURL = logsDir.appendingPathComponent("pdf.jsonl")
    try fileSystem.write(Data((jsonlLines.joined(separator: "\n") + "\n").utf8), to: logURL)

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try InfoFeature().run(.init(name: "pdf"))
    }

    expectNoDifference(
      result,
      .init(
        name: "pdf",
        path: "/Users/blob/.skillsync/skills/pdf",
        version: 3,
        state: "active",
        contentHash: "sha256:a1b2c3",
        created: "2025-02-06T00:00:00Z",
        source: "hand-authored",
        totalInvocations: 12,
        positive: 7,
        negative: 5
      )
    )
  }
}
