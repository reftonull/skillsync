import Testing

@testable import SkillSyncCore

@Suite
struct GitHubSkillSourceTests {
  @Test
  func parsesGitHubTreeURL() throws {
    let source = try GitHubSkillSource.parse(
      urlString: "https://github.com/acme/skills/tree/main/skills/review-assistant"
    )

    #expect(source.repo == "acme/skills")
    #expect(source.ref == "main")
    #expect(source.skillPath == "skills/review-assistant")
  }

  @Test
  func rejectsInvalidRepoFormat() {
    #expect(throws: GitHubSkillSource.ParseError.invalidRepo("acme")) {
      _ = try GitHubSkillSource(repo: "acme", skillPath: "skills/review-assistant", ref: "main")
    }
  }

  @Test
  func rejectsTraversalInSkillPath() {
    #expect(throws: GitHubSkillSource.ParseError.invalidSkillPath("../secret")) {
      _ = try GitHubSkillSource(repo: "acme/skills", skillPath: "../secret", ref: "main")
    }
  }

  @Test
  func rejectsEmptyRef() {
    #expect(throws: GitHubSkillSource.ParseError.invalidRef("")) {
      _ = try GitHubSkillSource(repo: "acme/skills", skillPath: "skills/review-assistant", ref: "")
    }
  }

  @Test
  func rejectsNonGitHubURL() {
    #expect(throws: GitHubSkillSource.ParseError.invalidURL("https://gitlab.com/acme/skills/tree/main/skills/foo")) {
      _ = try GitHubSkillSource.parse(urlString: "https://gitlab.com/acme/skills/tree/main/skills/foo")
    }
  }

  @Test
  func rejectsMalformedURL() {
    #expect(throws: GitHubSkillSource.ParseError.invalidURL("not-a-url")) {
      _ = try GitHubSkillSource.parse(urlString: "not-a-url")
    }
  }

  @Test
  func rejectsGitHubURLWithoutTreeComponent() {
    // URL has owner/repo but no /tree/<ref>/<path> structure
    #expect(throws: GitHubSkillSource.ParseError.invalidURL("https://github.com/acme/skills")) {
      _ = try GitHubSkillSource.parse(urlString: "https://github.com/acme/skills")
    }
  }

  @Test
  func rejectsGitHubURLWithBlobInsteadOfTree() {
    #expect(
      throws: GitHubSkillSource.ParseError.invalidURL(
        "https://github.com/acme/skills/blob/main/skills/foo/SKILL.md"
      )
    ) {
      _ = try GitHubSkillSource.parse(
        urlString: "https://github.com/acme/skills/blob/main/skills/foo/SKILL.md"
      )
    }
  }
}
