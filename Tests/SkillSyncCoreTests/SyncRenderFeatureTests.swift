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
          observation: .init(mode: .off)
        )
      )
    }

    expectNoDifference(
      result.targets.map { "\($0.target.id):\($0.status.rawValue):\($0.syncedSkills)" },
      ["codex:ok:1"]
    )
    let renderedMarkdownURL = URL(filePath: "/Users/blob/.skillsync/rendered/codex/pdf/SKILL.md")
    #expect(fileSystem.client.fileExists(renderedMarkdownURL.path))
    #expect(!fileSystem.client.fileExists("/Users/blob/.skillsync/rendered/codex/pdf/.meta.toml"))
    #expect(fileSystem.client.fileExists("/Users/blob/.codex/skills/pdf"))
    #expect(fileSystem.client.isSymbolicLink("/Users/blob/.codex/skills/pdf"))
    let linkTarget = try fileSystem.client.destinationOfSymbolicLink(
      URL(filePath: "/Users/blob/.codex/skills/pdf")
    )
    expectNoDifference(linkTarget.path, "/Users/blob/.skillsync/rendered/codex/pdf")

    let renderedMarkdown = String(
      decoding: try fileSystem.client.data(renderedMarkdownURL),
      as: UTF8.self
    )
    #expect(!renderedMarkdown.contains("<!-- skillsync:observation:start -->"))
    #expect(!renderedMarkdown.contains("<!-- skillsync:observation:end -->"))
  }

  @Test
  func injectsStaticObservationFooterIntoRenderedSkillMarkdownWhenModeOn() throws {
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
          observation: .init(mode: .on)
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
    #expect(renderedMarkdown.contains("After using this skill, run: skillsync observe <skill-name> --signal positive|negative [--note \"...\"]"))
    #expect(renderedMarkdown.contains("<!-- skillsync:observation:end -->"))
    #expect(!renderedMarkdown.contains("After completing this skill, assess whether the user was satisfied."))
    #expect(!renderedMarkdown.contains("skillsync log pdf --summary"))
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
          observation: .init(mode: .off)
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
          observation: .init(mode: .off)
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
          observation: .init(mode: .off)
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
          observation: .init(mode: .off)
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
