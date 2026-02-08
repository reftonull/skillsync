import Foundation
import Testing

@testable import SkillSyncCLI

extension BaseSuite {
  @Suite
  struct SkillNameCompletionTests {
    @Test
    func listsOnlyDirectoriesAndAppliesPrefixFilter() throws {
      let fileManager = FileManager.default
      let root = fileManager.temporaryDirectory
        .appendingPathComponent("skillsync-completion-\(UUID().uuidString)", isDirectory: true)
      let skillsDirectory = root.appendingPathComponent("skills", isDirectory: true)

      defer { try? fileManager.removeItem(at: root) }

      try fileManager.createDirectory(at: skillsDirectory, withIntermediateDirectories: true)
      try fileManager.createDirectory(
        at: skillsDirectory.appendingPathComponent("pdf", isDirectory: true),
        withIntermediateDirectories: true
      )
      try fileManager.createDirectory(
        at: skillsDirectory.appendingPathComponent("Prompting", isDirectory: true),
        withIntermediateDirectories: true
      )
      try Data("not-a-directory".utf8).write(
        to: skillsDirectory.appendingPathComponent("README.md", isDirectory: false)
      )

      let names = SkillNameCompletion.skillNames(in: skillsDirectory, prefix: "p")

      #expect(names == ["pdf", "Prompting"])
    }

    @Test
    func returnsEmptyWhenSkillsDirectoryIsMissing() {
      let missingDirectory = URL(
        filePath: "/tmp/skillsync-missing-\(UUID().uuidString)",
        directoryHint: .isDirectory
      )

      let names = SkillNameCompletion.skillNames(in: missingDirectory, prefix: "")

      #expect(names.isEmpty)
    }
  }
}
