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

    expectNoDifference(result.skillName, "existing-skill")
    #expect(result.createdMeta)
    #expect(result.contentHash.hasPrefix("sha256:"))

    let destinationRoot = URL(filePath: "/Users/blob/.skillsync/skills/existing-skill", directoryHint: .isDirectory)
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent("SKILL.md").path))
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent("scripts/run.sh").path))
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent(".meta.toml").path))

    let meta = try fileSystem.data(at: destinationRoot.appendingPathComponent(".meta.toml"))
    let metaText = String(decoding: meta, as: UTF8.self)
    #expect(metaText.contains("source = \"imported\""))
    #expect(metaText.contains("content-hash = \"\(result.contentHash)\""))
  }

  @Test
  func rejectsSourceWithoutSkillMarkdown() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.createDirectory(
      at: URL(filePath: "/Users/blob/project/no-skill", directoryHint: .isDirectory),
      withIntermediateDirectories: true
    )

    #expect(throws: AddFeature.Error.missingSkillMarkdown("/Users/blob/project/no-skill")) {
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

    #expect(!result.createdMeta)
    let meta = try fileSystem.data(
      at: URL(filePath: "/Users/blob/.skillsync/skills/existing-skill/.meta.toml")
    )
    let metaText = String(decoding: meta, as: UTF8.self)
    #expect(metaText.contains("source = \"custom\""))
    #expect(metaText.contains("content-hash = \"\(result.contentHash)\""))
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

    expectNoDifference(result.skillName, "review-assistant")
    #expect(result.createdMeta)

    let destinationRoot = URL(filePath: "/Users/blob/.skillsync/skills/review-assistant", directoryHint: .isDirectory)
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent("SKILL.md").path))
    #expect(fileSystem.client.fileExists(destinationRoot.appendingPathComponent("scripts/run.sh").path))
    let meta = try fileSystem.data(at: destinationRoot.appendingPathComponent(".meta.toml"))
    let metaText = String(decoding: meta, as: UTF8.self)
    #expect(metaText.contains("source = \"github\""))
    #expect(metaText.contains("repo = \"acme/skills\""))
    #expect(metaText.contains("skill-path = \"skills/review-assistant\""))
    #expect(metaText.contains("commit = \"abc123\""))
    #expect(metaText.contains("base-content-hash = \"\(result.contentHash)\""))
  }

  @Test
  func rejectsGitHubPayloadWithoutSkillMarkdown() throws {
    let fileSystem = InMemoryFileSystem()
    let source = try GitHubSkillSource(repo: "acme/skills", skillPath: "skills/no-markdown", ref: "main")

    #expect(throws: AddFeature.Error.missingSkillMarkdown("skills/no-markdown")) {
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

  @Test
  func rejectsSourcePathThatIsNotADirectory() throws {
    let fileSystem = InMemoryFileSystem()
    try fileSystem.write(
      Data("not a directory\n".utf8),
      to: URL(filePath: "/Users/blob/project/my-skill")
    )

    #expect(throws: AddFeature.Error.sourcePathNotDirectory("/Users/blob/project/my-skill")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try AddFeature().run(.init(sourcePath: "my-skill"))
      }
    }
  }

  @Test
  func rejectsSourcePathThatDoesNotExist() {
    let fileSystem = InMemoryFileSystem()

    #expect(throws: AddFeature.Error.sourcePathNotFound("/Users/blob/project/nonexistent")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
      } operation: {
        try AddFeature().run(.init(sourcePath: "nonexistent"))
      }
    }
  }

  @Test
  func rejectsGitHubPayloadWithPathTraversalFileName() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let source = try GitHubSkillSource(repo: "acme/skills", skillPath: "skills/review-assistant", ref: "main")

    #expect(throws: AddFeature.Error.invalidGitHubSkillPath("../traversal")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
        $0.githubSkillClient = GitHubSkillClient { _ in
          .init(
            files: [
              "SKILL.md": Data("# skill\n".utf8),
              "../traversal": Data("bad\n".utf8),
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

  @Test
  func escapesSpecialCharactersInUpstreamMetaTOML() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let source = try GitHubSkillSource(
      repo: "acme/skills",
      skillPath: "skills/review-assistant",
      ref: "main"
    )

    _ = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.githubSkillClient = GitHubSkillClient { _ in
        .init(
          files: ["SKILL.md": Data("# skill\n".utf8)],
          resolvedRef: "main",
          commit: #"abc\"123"#
        )
      }
      $0.date.now = Date(timeIntervalSince1970: 1_738_800_000)
    } operation: {
      try AddFeature().run(.init(githubSource: source))
    }

    let meta = try fileSystem.data(
      at: URL(filePath: "/Users/blob/.skillsync/skills/review-assistant/.meta.toml")
    )
    let metaText = String(decoding: meta, as: UTF8.self)
    // The backslash and quote must be escaped so the TOML remains valid
    #expect(metaText.contains(#"commit = "abc\\\"123""#))
  }
}
