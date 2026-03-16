import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct AddFeatureTests {
  @Test
  func importsSkillDirectoryAndCreatesMetaWhenMissing() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/existing-skill/scripts", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("# Existing Skill\n".utf8),
      to: URL(filePath: "/Users/blob/project/existing-skill/SKILL.md")
    )
    try fileSystem.write(
      Data("echo hi\n".utf8),
      to: URL(filePath: "/Users/blob/project/existing-skill/scripts/run.sh")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try AddFeature().run(.init(sourcePath: "existing-skill"))
    }

    #expect(result.skills.count == 1)
    let skill = result.skills[0]
    expectNoDifference(skill.skillName, "existing-skill")
    guard case let .imported(skillRoot, contentHash, createdMeta) = skill.status else {
      Issue.record("Expected imported status")
      return
    }
    #expect(createdMeta)
    #expect(contentHash.hasPrefix("sha256:"))

    let destinationRoot = URL(filePath: "/Users/blob/.skillsync/skills/existing-skill", directoryHint: .isDirectory)
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent("SKILL.md").path))
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent("scripts/run.sh").path))
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent(".meta.toml").path))

    let meta = try fileSystem.data(at: destinationRoot.appendingPathComponent(".meta.toml"))
    let metaText = String(decoding: meta, as: UTF8.self)
    #expect(metaText.contains("source = \"imported\""))
    #expect(metaText.contains("content-hash = \"\(contentHash)\""))
    #expect(skillRoot == destinationRoot)
  }

  @Test
  func rejectsSourceWithoutSkillMarkdownAndNoChildren() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/no-skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    #expect(throws: AddFeature.Error.noSkillsFound("/Users/blob/project/no-skill")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try AddFeature().run(.init(sourcePath: "no-skill"))
      }
    }
  }

  @Test
  func rejectsWhenDestinationSkillAlreadyExists() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/existing-skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("# Existing Skill\n".utf8),
      to: URL(filePath: "/Users/blob/project/existing-skill/SKILL.md")
    )
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/skills/existing-skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    #expect(throws: AddFeature.Error.skillAlreadyExists("existing-skill")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try AddFeature().run(.init(sourcePath: "existing-skill"))
      }
    }
  }

  @Test
  func preservesExistingMetaAndRefreshesContentHash() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/existing-skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(
      Data("# Existing Skill\n".utf8),
      to: URL(filePath: "/Users/blob/project/existing-skill/SKILL.md")
    )
    try fileSystem.write(
      Data(
        """
        [skill]
        source = "custom"
        content-hash = "sha256:old"
        """.utf8
      ),
      to: URL(filePath: "/Users/blob/project/existing-skill/.meta.toml")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try AddFeature().run(.init(sourcePath: "existing-skill"))
    }

    #expect(result.skills.count == 1)
    guard case let .imported(_, contentHash, createdMeta) = result.skills[0].status else {
      Issue.record("Expected imported status")
      return
    }
    #expect(!createdMeta)
    let meta = try fileSystem.data(
      at: URL(filePath: "/Users/blob/.skillsync/skills/existing-skill/.meta.toml")
    )
    let metaText = String(decoding: meta, as: UTF8.self)
    #expect(metaText.contains("source = \"custom\""))
    #expect(metaText.contains("content-hash = \"\(contentHash)\""))
    #expect(!metaText.contains("sha256:old"))
  }

  @Test
  func importsGitHubSkillAndWritesUpstreamMetadata() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let source = try GitHubSkillSource(
      repo: "acme/skills",
      skillPath: "skills/review-assistant",
      ref: "main"
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.githubSkillClient = GitHubSkillClient { input in
        #expect(input == source)
        return .init(
          files: [
            "SKILL.md": Data("# review-assistant\n".utf8),
            "scripts/run.sh": Data("echo hi\n".utf8),
          ],
          resolvedRef: "main",
          commit: "abc123"
        )
      }
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try AddFeature().run(.init(githubSource: source))
    }

    #expect(result.skills.count == 1)
    let skill = result.skills[0]
    expectNoDifference(skill.skillName, "review-assistant")
    guard case let .imported(_, contentHash, createdMeta) = skill.status else {
      Issue.record("Expected imported status")
      return
    }
    #expect(createdMeta)

    let destinationRoot = URL(
      filePath: "/Users/blob/.skillsync/skills/review-assistant", directoryHint: .isDirectory)
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent("SKILL.md").path))
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent("scripts/run.sh").path))
    let meta = try fileSystem.data(at: destinationRoot.appendingPathComponent(".meta.toml"))
    let metaText = String(decoding: meta, as: UTF8.self)
    #expect(metaText.contains("source = \"github\""))
    #expect(metaText.contains("repo = \"acme/skills\""))
    #expect(metaText.contains("skill-path = \"skills/review-assistant\""))
    #expect(metaText.contains("commit = \"abc123\""))
    #expect(metaText.contains("base-content-hash = \"\(contentHash)\""))
  }

  // MARK: - Batch import

  @Test
  func localBatchImportsValidChildrenAndSkipsInvalidAndExisting() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    // Parent with 4 children: alpha (valid), beta (valid), gamma (no SKILL.md), delta (already exists)
    let parent = "/Users/blob/project/all-skills"
    for name in ["alpha", "beta", "gamma", "delta"] {
      try fileSystem.createDirectory(
        at: URL(filePath: "\(parent)/\(name)", directoryHint: .isDirectory),
        withIntermediateDirectories: true
      )
    }
    try fileSystem.write(Data("# Alpha\n".utf8), to: URL(filePath: "\(parent)/alpha/SKILL.md"))
    try fileSystem.write(Data("# Beta\n".utf8), to: URL(filePath: "\(parent)/beta/SKILL.md"))
    // gamma has no SKILL.md
    try fileSystem.write(Data("# Delta\n".utf8), to: URL(filePath: "\(parent)/delta/SKILL.md"))

    // Pre-create delta in canonical store so it gets skipped
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/.skillsync/skills/delta", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try AddFeature().run(.init(sourcePath: "all-skills"))
    }

    // Should be sorted: alpha, beta, delta, gamma
    expectNoDifference(result.skills.map(\.skillName), ["alpha", "beta", "delta", "gamma"])

    // alpha and beta imported
    #expect(result.skills[0].status.isImported)
    #expect(result.skills[1].status.isImported)
    #expect(fileSystem.client.fileExists("/Users/blob/.skillsync/skills/alpha/SKILL.md"))
    #expect(fileSystem.client.fileExists("/Users/blob/.skillsync/skills/beta/SKILL.md"))

    // delta skipped (already exists)
    #expect(result.skills[2].status == .skippedExists)

    // gamma skipped (no SKILL.md)
    if case let .skippedInvalid(reason) = result.skills[3].status {
      #expect(reason.contains("SKILL.md"))
    } else {
      Issue.record("Expected skippedInvalid for gamma")
    }
  }

  @Test
  func gitHubBatchImportsChildrenWithCorrectSkillPaths() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let source = try GitHubSkillSource(repo: "acme/tools", skillPath: "skills", ref: "main")

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.githubSkillClient = GitHubSkillClient { _ in
        .init(
          files: [
            "skill-a/SKILL.md": Data("# Skill A\n".utf8),
            "skill-a/companion.txt": Data("extra\n".utf8),
            "skill-b/SKILL.md": Data("# Skill B\n".utf8),
          ],
          resolvedRef: "main",
          commit: "def456"
        )
      }
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try AddFeature().run(.init(githubSource: source))
    }

    expectNoDifference(result.skills.map(\.skillName), ["skill-a", "skill-b"])
    #expect(result.skills[0].status.isImported)
    #expect(result.skills[1].status.isImported)

    // Verify companion file preserved
    #expect(fileSystem.client.fileExists("/Users/blob/.skillsync/skills/skill-a/companion.txt"))

    // Verify per-child skill-path metadata
    let metaA = try fileSystem.data(
      at: URL(filePath: "/Users/blob/.skillsync/skills/skill-a/.meta.toml")
    )
    let metaTextA = String(decoding: metaA, as: UTF8.self)
    #expect(metaTextA.contains("skill-path = \"skills/skill-a\""))
    #expect(metaTextA.contains("commit = \"def456\""))

    let metaB = try fileSystem.data(
      at: URL(filePath: "/Users/blob/.skillsync/skills/skill-b/.meta.toml")
    )
    let metaTextB = String(decoding: metaB, as: UTF8.self)
    #expect(metaTextB.contains("skill-path = \"skills/skill-b\""))
  }

  @Test
  func gitHubBatchDropsRootLevelFiles() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let source = try GitHubSkillSource(repo: "acme/tools", skillPath: "skills", ref: "main")

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.githubSkillClient = GitHubSkillClient { _ in
        .init(
          files: [
            "README.md": Data("# readme\n".utf8),
            "child/SKILL.md": Data("# Child\n".utf8),
          ],
          resolvedRef: "main",
          commit: "abc"
        )
      }
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try AddFeature().run(.init(githubSource: source))
    }

    // Root-level README.md is silently dropped; only child/ is imported
    #expect(result.skills.count == 1)
    expectNoDifference(result.skills[0].skillName, "child")
    #expect(result.skills[0].status.isImported)
  }

  @Test
  func localBatchThrowsWhenNoValidChildren() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    // Parent with one child that has no SKILL.md
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/empty-parent/not-a-skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    #expect(throws: AddFeature.Error.noSkillsFound("/Users/blob/project/empty-parent")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try AddFeature().run(.init(sourcePath: "empty-parent"))
      }
    }
  }

  @Test
  func rootSkillMarkdownTakesPrecedenceOverChildren() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    // Directory with SKILL.md at root AND a child with SKILL.md
    let root = "/Users/blob/project/ambiguous"
    try fileSystem.createDirectory(
      at: URL(filePath: "\(root)/child", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )
    try fileSystem.write(Data("# Root skill\n".utf8), to: URL(filePath: "\(root)/SKILL.md"))
    try fileSystem.write(Data("# Child skill\n".utf8), to: URL(filePath: "\(root)/child/SKILL.md"))

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try AddFeature().run(.init(sourcePath: "ambiguous"))
    }

    // Should import as single skill, not batch
    #expect(result.skills.count == 1)
    expectNoDifference(result.skills[0].skillName, "ambiguous")
    #expect(result.skills[0].status.isImported)
  }

  @Test
  func rejectsGitHubPayloadWithoutSkillMarkdownAnywhere() throws {
    let fileSystem = InMemoryFileSystem()
    let source = try GitHubSkillSource(repo: "acme/skills", skillPath: "skills/no-markdown", ref: "main")

    #expect(throws: AddFeature.Error.noSkillsFound("skills/no-markdown")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.githubSkillClient = GitHubSkillClient { _ in
          .init(
            files: [
              "notes.txt": Data("no markdown\n".utf8)
            ],
            resolvedRef: "main",
            commit: "abc123"
          )
        }
      } operation: {
        try AddFeature().run(.init(githubSource: source))
      }
    }
  }
}
