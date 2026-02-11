import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct UpdateFeatureTests {
  @Test
  func updatesGitHubManagedSkillWhenContentChanges() throws {
    let fileSystem = InMemoryFileSystem()
    let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/review-assistant", directoryHint: .isDirectory)
    try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
    try fileSystem.write(Data("# old\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))

    let oldHash = try hashSkill(skillRoot: skillRoot, fileSystem: fileSystem)
    try fileSystem.write(
      Data(
        """
        [skill]
        source = "github"
        version = 1
        content-hash = "\(oldHash)"
        state = "active"

        [upstream]
        repo = "acme/skills"
        skill-path = "skills/review-assistant"
        ref = "main"
        commit = "oldcommit"
        base-content-hash = "\(oldHash)"
        """.utf8
      ),
      to: skillRoot.appendingPathComponent(".meta.toml")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.githubSkillClient = GitHubSkillClient { _ in
        .init(
          files: [
            "SKILL.md": Data("# new\n".utf8),
            "scripts/run.sh": Data("echo hi\n".utf8),
          ],
          resolvedRef: "main",
          commit: "newcommit"
        )
      }
    } operation: {
      try UpdateFeature().run(.init(name: "review-assistant"))
    }

    #expect(result.updated)
    let skillMarkdown = try fileSystem.data(at: skillRoot.appendingPathComponent("SKILL.md"))
    #expect(String(decoding: skillMarkdown, as: UTF8.self).contains("# new"))
    #expect(fileSystem.client.fileExists(skillRoot.appendingPathComponent("scripts/run.sh").path))

    let meta = try fileSystem.data(at: skillRoot.appendingPathComponent(".meta.toml"))
    let metaText = String(decoding: meta, as: UTF8.self)
    #expect(metaText.contains("version = 2"))
    #expect(metaText.contains("commit = \"newcommit\""))
    #expect(metaText.contains("base-content-hash = \"\(result.contentHash)\""))
    #expect(metaText.contains("content-hash = \"\(result.contentHash)\""))
  }

  @Test
  func refusesUpdateWhenSkillDivergedLocally() throws {
    let fileSystem = InMemoryFileSystem()
    let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/review-assistant", directoryHint: .isDirectory)
    try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
    try fileSystem.write(Data("# initial\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))

    let baseHash = try hashSkill(skillRoot: skillRoot, fileSystem: fileSystem)
    try fileSystem.write(
      Data(
        """
        [skill]
        source = "github"
        version = 1
        content-hash = "\(baseHash)"
        state = "active"

        [upstream]
        repo = "acme/skills"
        skill-path = "skills/review-assistant"
        ref = "main"
        commit = "oldcommit"
        base-content-hash = "\(baseHash)"
        """.utf8
      ),
      to: skillRoot.appendingPathComponent(".meta.toml")
    )

    try fileSystem.write(Data("# local edits\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))

    #expect(throws: UpdateFeature.Error.localSkillDiverged("review-assistant")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.githubSkillClient = GitHubSkillClient { _ in
          .init(files: ["SKILL.md": Data("# upstream\n".utf8)], resolvedRef: "main", commit: "newcommit")
        }
      } operation: {
        try UpdateFeature().run(.init(name: "review-assistant"))
      }
    }
  }

  @Test
  func forceOverridesLocalDivergence() throws {
    let fileSystem = InMemoryFileSystem()
    let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/review-assistant", directoryHint: .isDirectory)
    try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
    try fileSystem.write(Data("# initial\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))

    let baseHash = try hashSkill(skillRoot: skillRoot, fileSystem: fileSystem)
    try fileSystem.write(
      Data(
        """
        [skill]
        source = "github"
        version = 1
        content-hash = "\(baseHash)"
        state = "active"

        [upstream]
        repo = "acme/skills"
        skill-path = "skills/review-assistant"
        ref = "main"
        commit = "oldcommit"
        base-content-hash = "\(baseHash)"
        """.utf8
      ),
      to: skillRoot.appendingPathComponent(".meta.toml")
    )

    try fileSystem.write(Data("# local edits\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.githubSkillClient = GitHubSkillClient { _ in
        .init(files: ["SKILL.md": Data("# upstream\n".utf8)], resolvedRef: "main", commit: "newcommit")
      }
    } operation: {
      try UpdateFeature().run(.init(name: "review-assistant", force: true))
    }

    #expect(result.updated)
    let skillMarkdown = try fileSystem.data(at: skillRoot.appendingPathComponent("SKILL.md"))
    #expect(String(decoding: skillMarkdown, as: UTF8.self).contains("# upstream"))
  }

  @Test
  func reportsUpToDateWhenHashesMatch() throws {
    let fileSystem = InMemoryFileSystem()
    let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/review-assistant", directoryHint: .isDirectory)
    try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
    try fileSystem.write(Data("# same\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))

    let baseHash = try hashSkill(skillRoot: skillRoot, fileSystem: fileSystem)
    try fileSystem.write(
      Data(
        """
        [skill]
        source = "github"
        version = 1
        content-hash = "\(baseHash)"
        state = "active"

        [upstream]
        repo = "acme/skills"
        skill-path = "skills/review-assistant"
        ref = "main"
        commit = "oldcommit"
        base-content-hash = "\(baseHash)"
        """.utf8
      ),
      to: skillRoot.appendingPathComponent(".meta.toml")
    )

    let result = try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
      $0.githubSkillClient = GitHubSkillClient { _ in
        .init(files: ["SKILL.md": Data("# same\n".utf8)], resolvedRef: "main", commit: "freshcommit")
      }
    } operation: {
      try UpdateFeature().run(.init(name: "review-assistant"))
    }

    #expect(!result.updated)

    let meta = try fileSystem.data(at: skillRoot.appendingPathComponent(".meta.toml"))
    let metaText = String(decoding: meta, as: UTF8.self)
    #expect(metaText.contains("version = 1"))
    #expect(metaText.contains("commit = \"freshcommit\""))
  }

  @Test
  func rejectsNonGitHubSkill() throws {
    let fileSystem = InMemoryFileSystem()
    let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/review-assistant", directoryHint: .isDirectory)
    try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
    try fileSystem.write(Data("# local\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))
    try fileSystem.write(
      Data(
        """
        [skill]
        source = "imported"
        version = 1
        state = "active"
        """.utf8
      ),
      to: skillRoot.appendingPathComponent(".meta.toml")
    )

    #expect(throws: UpdateFeature.Error.notGitHubManaged("review-assistant")) {
      try withDependencies {
        $0.pathClient = PathClient(
          homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
          currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
        )
        $0.fileSystemClient = fileSystem.client
        $0.githubSkillClient = GitHubSkillClient { _ in
          .init(files: ["SKILL.md": Data("# upstream\n".utf8)], resolvedRef: "main", commit: "newcommit")
        }
      } operation: {
        try UpdateFeature().run(.init(name: "review-assistant"))
      }
    }
  }

  private func hashSkill(skillRoot: URL, fileSystem: InMemoryFileSystem) throws -> String {
    try withDependencies {
      $0.pathClient = PathClient(
        homeDirectory: { fileSystem.homeDirectoryForCurrentUser },
        currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
      )
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SkillContentHashFeature().run(skillDirectory: skillRoot)
    }
  }
}
