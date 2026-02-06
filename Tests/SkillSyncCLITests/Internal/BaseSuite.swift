import Dependencies
import DependenciesTestSupport
import SnapshotTesting
import Testing

@testable import SkillSyncCLI

@Suite(
  .serialized,
  .snapshots(record: .missing),
  .dependencies {
    $0.uuid = .incrementing
  }
)
@MainActor
struct BaseSuite {}
