import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct SyncRenderFeatureTests {
  @Test
  func rendersActiveSkillsAndSymlinksDestination() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.codex/skills", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      _ = try NewFeature().run(
        .init(name: "pdf", description: "Extract text from PDFs.")
      )
    }

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SyncRenderFeature().run(
        .init(
          targets: [
            .init(
              id: "codex",
              path: "/Users/blob/.codex/skills",
              source: .tool
            )
          ],
          observation: .init(mode: .off, threshold: 0.3, minInvocations: 5)
        )
      )
    }

    expectNoDifference(
      result.targets.map { "\($0.target.id):\($0.status.rawValue):\($0.syncedSkills)" },
      ["codex:ok:1"]
    )
    #expect(fileSystem.client.fileExists("/Users/blob/.skillsync/rendered/codex/pdf/SKILL.md"))
    #expect(!fileSystem.client.fileExists("/Users/blob/.skillsync/rendered/codex/pdf/.meta.toml"))
    #expect(fileSystem.client.fileExists("/Users/blob/.codex/skills/pdf"))
    #expect(fileSystem.client.isSymbolicLink("/Users/blob/.codex/skills/pdf"))
    let linkTarget = try fileSystem.client.destinationOfSymbolicLink(
      URL(filePath: "/Users/blob/.codex/skills/pdf")
    )
    expectNoDifference(linkTarget.path, "/Users/blob/.skillsync/rendered/codex/pdf")
  }

  @Test
  func injectsAutoObservationFooterIntoRenderedSkillMarkdown() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.codex/skills", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      _ = try NewFeature().run(
        .init(name: "pdf", description: "Extract text from PDFs.")
      )
    }

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SyncRenderFeature().run(
        .init(
          targets: [
            .init(
              id: "codex",
              path: "/Users/blob/.codex/skills",
              source: .tool
            )
          ],
          observation: .init(mode: .auto, threshold: 0.3, minInvocations: 5)
        )
      )
    }

    let renderedMarkdown = String(
      decoding: try fileSystem.client.data(
        URL(filePath: "/Users/blob/.skillsync/rendered/codex/pdf/SKILL.md")
      ),
      as: UTF8.self
    )
    #expect(renderedMarkdown.contains("<!-- skillsync:observation:start -->"))
    #expect(renderedMarkdown.contains("skillsync observe pdf --signal <positive|negative>"))
    #expect(renderedMarkdown.contains("<!-- skillsync:observation:end -->"))
  }

  @Test
  func bestEffortContinuesWhenOneDestinationFails() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/tmp/ok", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/tmp/conflict", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      _ = try NewFeature().run(
        .init(name: "pdf", description: "Extract text from PDFs.")
      )
    }
    try fileSystem.write(
      Data("occupied\n".utf8),
      to: URL(filePath: "/tmp/conflict/pdf")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SyncRenderFeature().run(
        .init(
          targets: [
            .init(
              id: "conflict",
              path: "/tmp/conflict",
              source: .path
            ),
            .init(
              id: "ok",
              path: "/tmp/ok",
              source: .path
            ),
          ],
          observation: .init(mode: .off, threshold: 0.3, minInvocations: 5)
        )
      )
    }

    expectNoDifference(
      result.targets.map { "\($0.target.id):\($0.status.rawValue)" },
      ["conflict:failed", "ok:ok"]
    )
    #expect(fileSystem.client.fileExists("/tmp/ok/pdf"))
    #expect(fileSystem.client.isSymbolicLink("/tmp/ok/pdf"))
  }

  @Test
  func prunesPendingRemoveSkillOnSuccessfulSync() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.codex/skills", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      _ = try NewFeature().run(
        .init(name: "pdf", description: "Extract text from PDFs.")
      )
      _ = try SyncRenderFeature().run(
        .init(
          targets: [
            .init(
              id: "codex",
              path: "/Users/blob/.codex/skills",
              source: .tool
            )
          ],
          observation: .init(mode: .off, threshold: 0.3, minInvocations: 5)
        )
      )
      _ = try RmFeature().run(.init(name: "pdf"))
      _ = try SyncRenderFeature().run(
        .init(
          targets: [
            .init(
              id: "codex",
              path: "/Users/blob/.codex/skills",
              source: .tool
            )
          ],
          observation: .init(mode: .off, threshold: 0.3, minInvocations: 5)
        )
      )
    }

    #expect(!fileSystem.client.fileExists("/Users/blob/.codex/skills/pdf"))
    #expect(!fileSystem.client.fileExists("/Users/blob/.skillsync/rendered/codex/pdf"))
    #expect(!fileSystem.client.fileExists("/Users/blob/.skillsync/skills/pdf"))
  }

  @Test
  func doesNotPrunePendingRemoveFromCanonicalStoreWhenAnyDestinationFails() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/tmp/ok", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/tmp", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("not a directory\n".utf8),
      to: URL(filePath: "/tmp/conflict")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      _ = try NewFeature().run(
        .init(name: "pdf", description: "Extract text from PDFs.")
      )
      _ = try RmFeature().run(.init(name: "pdf"))
      return try SyncRenderFeature().run(
        .init(
          targets: [
            .init(
              id: "conflict",
              path: "/tmp/conflict",
              source: .path
            ),
            .init(
              id: "ok",
              path: "/tmp/ok",
              source: .path
            ),
          ],
          observation: .init(mode: .off, threshold: 0.3, minInvocations: 5)
        )
      )
    }

    expectNoDifference(
      result.targets.map { "\($0.target.id):\($0.status.rawValue)" },
      ["conflict:failed", "ok:ok"]
    )
    #expect(fileSystem.client.fileExists("/Users/blob/.skillsync/skills/pdf"))
  }
}
