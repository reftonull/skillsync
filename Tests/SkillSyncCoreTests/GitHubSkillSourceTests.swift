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
}
