import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct InitFeatureTests {
  private static let fixtureBuiltInSkills: [BuiltInSkill] = [
    BuiltInSkill(
      name: "skillsync-new",
      files: [
        "SKILL.md": Data("# skillsync-new\n".utf8),
      ]
    ),
    BuiltInSkill(
      name: "skillsync-check",
      files: [
        "SKILL.md": Data("# skillsync-check\n".utf8),
      ]
    ),
    BuiltInSkill(
      name: "skillsync-refine",
      files: [
        "SKILL.md": Data("# skillsync-refine\n".utf8),
        "scripts/check.sh": Data("#!/bin/sh\necho check\n".utf8),
      ]
    ),
  ]

  @Test
  func createsStoreDirectoriesAndConfig() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.builtInSkillsClient = BuiltInSkillsClient(
        load: { Self.fixtureBuiltInSkills }
      )
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try InitFeature().run()
    }

    let store = URL(filePath: "/Users/blob/.skillsync", directoryHint: .isDirectory)
    #expect(result == .init(storeRoot: store, createdConfig: true))
    #expect(fileSystem.client.fileExists(store.appendingPathComponent("skills").path))
    #expect(fileSystem.client.fileExists(store.appendingPathComponent("rendered").path))
    #expect(fileSystem.client.fileExists(store.appendingPathComponent("logs").path))
    #expect(fileSystem.client.fileExists(store.appendingPathComponent("config.toml").path))

    let builtInSkills = Self.fixtureBuiltInSkills
    #expect(!builtInSkills.isEmpty)
    for builtIn in builtInSkills {
      let builtInRoot = store.appendingPathComponent("skills/\(builtIn.name)", isDirectory: true)
      #expect(fileSystem.client.fileExists(builtInRoot.path))
      #expect(fileSystem.client.fileExists(builtInRoot.appendingPathComponent(".meta.toml").path))

      #expect(!builtIn.files.isEmpty)
      for relativePath in builtIn.files.keys.sorted() {
        #expect(fileSystem.client.fileExists(builtInRoot.appendingPathComponent(relativePath).path))
      }

      let metaData = try fileSystem.data(at: builtInRoot.appendingPathComponent(".meta.toml"))
      let meta = String(decoding: metaData, as: UTF8.self)
      #expect(meta.contains("source = \"built-in\""))
      #expect(meta.contains("state = \"active\""))
      #expect(meta.contains("version = 1"))
      #expect(meta.contains("content-hash = \"sha256:"))
      #expect(meta.contains("total-invocations = 0"))
      #expect(meta.contains("positive = 0"))
      #expect(meta.contains("negative = 0"))
    }

    let config = try fileSystem.data(at: store.appendingPathComponent("config.toml"))
    let configContents = String(decoding: config, as: UTF8.self)
    #expect(!configContents.contains("[tools.claude-code]"))
    #expect(!configContents.contains("[tools.codex]"))
    #expect(!configContents.contains("[tools.cursor]"))
    #expect(configContents.contains("[observation]"))
    #expect(configContents.contains("mode = \"on\""))
    #expect(!configContents.contains("threshold ="))
    #expect(!configContents.contains("min_invocations ="))
  }

  @Test
  func isIdempotentAndDoesNotOverwriteExistingConfig() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let store = URL(filePath: "/Users/blob/.skillsync", directoryHint: .isDirectory)
    try fileSystem.createDirectory(at: store, withIntermediateDirectories: true)
    let builtInSkills = Self.fixtureBuiltInSkills
    #expect(!builtInSkills.isEmpty)
    let existingBuiltIn = try #require(builtInSkills.first)
    let config = store.appendingPathComponent("config.toml")
    fileSystem.setFile(Data("custom = true\n".utf8), atPath: config.path)
    let builtInRoot = store.appendingPathComponent("skills/\(existingBuiltIn.name)", isDirectory: true)
    try fileSystem.createDirectory(at: builtInRoot, withIntermediateDirectories: true)
    let builtInMarkdown = builtInRoot.appendingPathComponent("SKILL.md")
    let builtInMeta = builtInRoot.appendingPathComponent(".meta.toml")
    try fileSystem.write(Data("# custom-built-in\n\ncustom\n".utf8), to: builtInMarkdown)
    try fileSystem.write(
      Data(
        """
        [skill]
        created = "2026-01-01T00:00:00Z"
        source = "custom"
        version = 99
        content-hash = "sha256:custom"
        state = "active"

        [stats]
        total-invocations = 0
        positive = 0
        negative = 0
        """.utf8
      ),
      to: builtInMeta
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.builtInSkillsClient = BuiltInSkillsClient(
        load: { Self.fixtureBuiltInSkills }
      )
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try InitFeature().run()
    }

    #expect(result == .init(storeRoot: store, createdConfig: false))
    let configData = try fileSystem.data(at: config)
    #expect(String(decoding: configData, as: UTF8.self) == "custom = true\n")
    let markdownData = try fileSystem.data(at: builtInMarkdown)
    #expect(String(decoding: markdownData, as: UTF8.self) == "# custom-built-in\n\ncustom\n")
    let metaData = try fileSystem.data(at: builtInMeta)
    #expect(String(decoding: metaData, as: UTF8.self).contains("source = \"custom\""))

    for builtIn in builtInSkills {
      let path = store.appendingPathComponent("skills/\(builtIn.name)", isDirectory: true)
      #expect(fileSystem.client.fileExists(path.path))
      #expect(fileSystem.client.fileExists(path.appendingPathComponent(".meta.toml").path))
      for relativePath in builtIn.files.keys.sorted() {
        #expect(fileSystem.client.fileExists(path.appendingPathComponent(relativePath).path))
      }
    }
  }
}
