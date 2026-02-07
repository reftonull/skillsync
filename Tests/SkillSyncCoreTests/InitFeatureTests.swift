import Dependencies
import DependenciesTestSupport
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct InitFeatureTests {
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
    } operation: {
      try InitFeature().run()
    }

    let store = URL(filePath: "/Users/blob/.skillsync", directoryHint: .isDirectory)
    #expect(result == .init(storeRoot: store, createdConfig: true))
    #expect(fileSystem.client.fileExists(store.appendingPathComponent("skills").path))
    #expect(fileSystem.client.fileExists(store.appendingPathComponent("editing").path))
    #expect(fileSystem.client.fileExists(store.appendingPathComponent("locks").path))
    #expect(fileSystem.client.fileExists(store.appendingPathComponent("rendered").path))
    #expect(fileSystem.client.fileExists(store.appendingPathComponent("logs").path))
    #expect(fileSystem.client.fileExists(store.appendingPathComponent("config.toml").path))
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
    let config = store.appendingPathComponent("config.toml")
    fileSystem.setFile(Data("custom = true\n".utf8), atPath: config.path)

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try InitFeature().run()
    }

    #expect(result == .init(storeRoot: store, createdConfig: false))
    let configData = try fileSystem.data(at: config)
    #expect(String(decoding: configData, as: UTF8.self) == "custom = true\n")
  }
}
