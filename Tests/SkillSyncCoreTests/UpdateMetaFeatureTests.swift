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

  @Test
  func readsTypedValuesFromMeta() throws {
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
        state = "active"
        version = 12
        content-hash = "sha256:abc"
        created = "2026-02-06T00:00:00Z"
        source = "hand-authored"
        """.utf8
      ),
      to: metaURL
    )

    let document = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: metaURL)
    }

    expectNoDifference(document.skill.state, "active")
    expectNoDifference(document.skill.version, 12)
    expectNoDifference(document.skill.contentHash, "sha256:abc")
    expectNoDifference(document.skill.created, "2026-02-06T00:00:00Z")
    expectNoDifference(document.skill.source, "hand-authored")
  }

  @Test
  func readsUpstreamSection() throws {
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
        source = "github"

        [upstream]
        repo = "owner/repo"
        skill-path = "skills/pdf"
        ref = "main"
        commit = "abc123"
        base-content-hash = "sha256:def"
        """.utf8
      ),
      to: metaURL
    )

    let document = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: metaURL)
    }

    expectNoDifference(document.skill.source, "github")
    expectNoDifference(document.upstream.repo, "owner/repo")
    expectNoDifference(document.upstream.skillPath, "skills/pdf")
    expectNoDifference(document.upstream.ref, "main")
    expectNoDifference(document.upstream.commit, "abc123")
    expectNoDifference(document.upstream.baseContentHash, "sha256:def")
  }

  @Test
  func readsEmptyDocumentForMissingOrInvalidMeta() throws {
    let fileSystem = InMemoryFileSystem()
    let missingURL = URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
    let invalidURL = URL(filePath: "/Users/blob/.skillsync/skills/csv/.meta.toml")
    try fileSystem.createDirectory(
      at: invalidURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try fileSystem.write(Data([0xFF, 0xFE, 0x00]), to: invalidURL)

    let missing = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: missingURL)
    }
    let invalid = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: invalidURL)
    }

    expectNoDifference(missing.skill.state, nil)
    expectNoDifference(invalid.skill.state, nil)
  }
}
