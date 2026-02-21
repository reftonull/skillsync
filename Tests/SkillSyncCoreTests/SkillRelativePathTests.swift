import Testing

@testable import SkillSyncCore

@Suite
struct SkillRelativePathTests {
  // MARK: - Valid paths

  @Test
  func sanitizesSimpleName() {
    #expect(SkillRelativePath.sanitize("SKILL.md") == "SKILL.md")
  }

  @Test
  func sanitizesNestedPath() {
    #expect(SkillRelativePath.sanitize("scripts/run.sh") == "scripts/run.sh")
  }

  @Test
  func stripsLeadingSlash() {
    #expect(SkillRelativePath.sanitize("/SKILL.md") == "SKILL.md")
  }

  @Test
  func stripsTrailingSlash() {
    #expect(SkillRelativePath.sanitize("scripts/") == "scripts")
  }

  @Test
  func stripsBothLeadingAndTrailingSlashes() {
    #expect(SkillRelativePath.sanitize("/scripts/run.sh/") == "scripts/run.sh")
  }

  @Test
  func collapsesDoubleSlashesViaComponents() {
    #expect(SkillRelativePath.sanitize("scripts//run.sh") == "scripts/run.sh")
  }

  // MARK: - Rejected paths (path traversal / security)

  @Test
  func rejectsDotDotComponent() {
    #expect(SkillRelativePath.sanitize("../secret") == nil)
  }

  @Test
  func rejectsDotDotInMiddle() {
    #expect(SkillRelativePath.sanitize("scripts/../secret") == nil)
  }

  @Test
  func rejectsDotComponent() {
    #expect(SkillRelativePath.sanitize("./SKILL.md") == nil)
  }

  @Test
  func rejectsDotInMiddle() {
    #expect(SkillRelativePath.sanitize("scripts/./run.sh") == nil)
  }

  @Test
  func rejectsEmptyString() {
    #expect(SkillRelativePath.sanitize("") == nil)
  }

  @Test
  func rejectsSlashOnly() {
    #expect(SkillRelativePath.sanitize("/") == nil)
  }

  @Test
  func rejectsMultipleSlashesOnly() {
    #expect(SkillRelativePath.sanitize("///") == nil)
  }
}
