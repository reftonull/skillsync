import Testing

@testable import SkillSyncCLI

extension BaseSuite {
  @Suite
  struct VersionCommandTests {
    @Test
    func version() async throws {
      try await assertCommand(["version"]) {
        """
        skillsync 0.1.0
        """
      }
    }
  }
}
