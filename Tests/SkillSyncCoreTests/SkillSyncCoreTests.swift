import CustomDump
import Testing

@testable import SkillSyncCore

@Suite
struct SkillSyncCoreTests {
  @Test
  func moduleLoads() {
    expectNoDifference(String(describing: SkillSyncCore.self), "SkillSyncCore")
  }
}
