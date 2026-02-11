import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct LsFeatureTests {
  @Test
  func returnsEmptyWhenNoSkillsDirectoryExists() throws {
    let fileSystem = InMemoryFileSystem()

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LsFeature().run()
    }

    expectNoDifference(result.skills, [])
  }

  @Test
  func listsSkillsSortedWithStateAndStats() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      _ = try NewFeature().run(.init(name: "shell", description: nil))
      _ = try NewFeature().run(.init(name: "pdf", description: nil))
    }

    let shellMetaURL = URL(filePath: "/Users/blob/.skillsync/skills/shell/.meta.toml")
    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().run(
        metaURL: shellMetaURL,
        updates: [
          .init(section: "skill", key: "state", operation: .setString("pending_remove"))
        ]
      )
    }

    let logsDir = URL(filePath: "/Users/blob/.skillsync/logs", directoryHint: .isDirectory)
    try fileSystem.createDirectory(at: logsDir, withIntermediateDirectories: true)
    var jsonlLines: [String] = []
    for i in 0..<7 {
      jsonlLines.append(#"{"ts":"2025-02-06T00:0\#(i):00Z","signal":"positive","version":1}"#)
    }
    for i in 0..<3 {
      jsonlLines.append(#"{"ts":"2025-02-06T01:0\#(i):00Z","signal":"negative","version":1}"#)
    }
    let logURL = logsDir.appendingPathComponent("shell.jsonl")
    try fileSystem.write(Data((jsonlLines.joined(separator: "\n") + "\n").utf8), to: logURL)

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try LsFeature().run()
    }

    expectNoDifference(
      result.skills,
      [
        .init(name: "pdf", state: "active", totalInvocations: 0, positive: 0, negative: 0),
        .init(name: "shell", state: "pending_remove", totalInvocations: 10, positive: 7, negative: 3),
      ]
    )
  }
}
