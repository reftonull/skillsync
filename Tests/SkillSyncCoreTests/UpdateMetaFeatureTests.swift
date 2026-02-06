import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct UpdateMetaFeatureTests {
  @Test
  func updatesExistingFieldInSection() throws {
    let fileSystem = InMemoryFileSystem()
    let metaURL = URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
    try fileSystem.createDirectory(
      at: metaURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data(
        """
        [skill]
        content-hash = "sha256:old"
        version = 1
        """.utf8
      ),
      to: metaURL
    )

    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().run(
        metaURL: metaURL,
        updates: [
          .init(
            section: "skill",
            key: "content-hash",
            operation: .setString("sha256:new")
          )
        ]
      )
    }

    let updated = try fileSystem.data(at: metaURL)
    expectNoDifference(
      String(decoding: updated, as: UTF8.self),
      """
      [skill]
      content-hash = "sha256:new"
      version = 1
      """
    )
  }

  @Test
  func appendsMissingKeyInExistingSection() throws {
    let fileSystem = InMemoryFileSystem()
    let metaURL = URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
    try fileSystem.createDirectory(
      at: metaURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data(
        """
        [skill]
        version = 1
        """.utf8
      ),
      to: metaURL
    )

    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().run(
        metaURL: metaURL,
        updates: [
          .init(
            section: "skill",
            key: "state",
            operation: .setString("pending_remove")
          )
        ]
      )
    }

    let updated = try fileSystem.data(at: metaURL)
    expectNoDifference(
      String(decoding: updated, as: UTF8.self),
      """
      [skill]
      version = 1
      state = "pending_remove"
      """
    )
  }

  @Test
  func createsMissingSectionWhenNeeded() throws {
    let fileSystem = InMemoryFileSystem()
    let metaURL = URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
    try fileSystem.createDirectory(
      at: metaURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data(
        """
        [skill]
        version = 1
        """.utf8
      ),
      to: metaURL
    )

    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().run(
        metaURL: metaURL,
        updates: [
          .init(
            section: "stats",
            key: "positive",
            operation: .setInt(3)
          )
        ]
      )
    }

    let updated = try fileSystem.data(at: metaURL)
    expectNoDifference(
      String(decoding: updated, as: UTF8.self),
      """
      [skill]
      version = 1

      [stats]
      positive = 3
      """
    )
  }

  @Test
  func incrementsIntegerFields() throws {
    let fileSystem = InMemoryFileSystem()
    let metaURL = URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
    try fileSystem.createDirectory(
      at: metaURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data(
        """
        [stats]
        total-invocations = 10
        positive = 7
        """.utf8
      ),
      to: metaURL
    )

    try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().run(
        metaURL: metaURL,
        updates: [
          .init(section: "stats", key: "total-invocations", operation: .incrementInt(1)),
          .init(section: "stats", key: "positive", operation: .incrementInt(1)),
          .init(section: "stats", key: "negative", operation: .incrementInt(1)),
        ]
      )
    }

    let updated = try fileSystem.data(at: metaURL)
    expectNoDifference(
      String(decoding: updated, as: UTF8.self),
      """
      [stats]
      total-invocations = 11
      positive = 8
      negative = 1
      """
    )
  }
}
