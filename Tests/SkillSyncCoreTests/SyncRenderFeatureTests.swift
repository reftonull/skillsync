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
    #expect(renderedMarkdown.contains("skillsync observe <skill-name> --signal positive"))
    #expect(renderedMarkdown.contains("skillsync observe <skill-name> --signal negative --note"))
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
  func syncBumpsVersionWhenContentChanged() throws {
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

    let metaURL = URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
    let metaBefore = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: metaURL)
    }
    let versionBefore = metaBefore.int(section: "skill", key: "version")
    let hashBefore = metaBefore.string(section: "skill", key: "content-hash")

    // Modify the skill content directly
    let skillMD = URL(filePath: "/Users/blob/.skillsync/skills/pdf/SKILL.md")
    try fileSystem.write(Data("Updated content\n".utf8), to: skillMD)

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
          observation: .init(mode: .off)
        )
      )
    }

    let metaAfter = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: metaURL)
    }
    let versionAfter = metaAfter.int(section: "skill", key: "version")
    let hashAfter = metaAfter.string(section: "skill", key: "content-hash")

    #expect(versionAfter == (versionBefore ?? 0) + 1)
    #expect(hashAfter != hashBefore)
  }

  @Test
  func syncDoesNotBumpVersionWhenContentUnchanged() throws {
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

    let targets: [SyncTarget] = [
      .init(id: "codex", path: "/Users/blob/.codex/skills", source: .tool)
    ]
    let observation = ObservationSettings(mode: .off)

    // First sync
    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SyncRenderFeature().run(.init(targets: targets, observation: observation))
    }

    let metaURL = URL(filePath: "/Users/blob/.skillsync/skills/pdf/.meta.toml")
    let metaAfterFirst = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: metaURL)
    }
    let versionAfterFirst = metaAfterFirst.int(section: "skill", key: "version")
    let hashAfterFirst = metaAfterFirst.string(section: "skill", key: "content-hash")

    // Second sync with no changes
    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SyncRenderFeature().run(.init(targets: targets, observation: observation))
    }

    let metaAfterSecond = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: metaURL)
    }
    let versionAfterSecond = metaAfterSecond.int(section: "skill", key: "version")
    let hashAfterSecond = metaAfterSecond.string(section: "skill", key: "content-hash")

    expectNoDifference(versionAfterSecond, versionAfterFirst)
    expectNoDifference(hashAfterSecond, hashAfterFirst)
  }

  @Test
  func syncHandlesMultipleSkillsWithMixedChanges() throws {
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
        .init(name: "alpha", description: "Alpha skill")
      )
      _ = try NewFeature().run(
        .init(name: "beta", description: "Beta skill")
      )
    }

    let targets: [SyncTarget] = [
      .init(id: "codex", path: "/Users/blob/.codex/skills", source: .tool)
    ]
    let observation = ObservationSettings(mode: .off)

    // First sync to establish baseline
    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SyncRenderFeature().run(.init(targets: targets, observation: observation))
    }

    let alphaMetaURL = URL(filePath: "/Users/blob/.skillsync/skills/alpha/.meta.toml")
    let betaMetaURL = URL(filePath: "/Users/blob/.skillsync/skills/beta/.meta.toml")

    let alphaVersionBefore = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: alphaMetaURL).int(section: "skill", key: "version")
    }
    let betaVersionBefore = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: betaMetaURL).int(section: "skill", key: "version")
    }

    // Only modify alpha
    let alphaMD = URL(filePath: "/Users/blob/.skillsync/skills/alpha/SKILL.md")
    try fileSystem.write(Data("Changed alpha content\n".utf8), to: alphaMD)

    // Second sync
    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SyncRenderFeature().run(.init(targets: targets, observation: observation))
    }

    let alphaVersionAfter = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: alphaMetaURL).int(section: "skill", key: "version")
    }
    let betaVersionAfter = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try UpdateMetaFeature().read(metaURL: betaMetaURL).int(section: "skill", key: "version")
    }

    // Alpha should have bumped
    #expect(alphaVersionAfter == (alphaVersionBefore ?? 0) + 1)
    // Beta should not have changed
    expectNoDifference(betaVersionAfter, betaVersionBefore)
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
