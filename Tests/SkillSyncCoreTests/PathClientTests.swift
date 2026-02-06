import CustomDump
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct PathClientTests {
  @Test
  func resolvePathExpandsTildePrefix() {
    let client = PathClient(
      homeDirectory: { URL(filePath: "/Users/blob", directoryHint: .isDirectory) },
      currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
    )

    expectNoDifference(
      client.resolvePath("~/custom-cursor-skills").path,
      "/Users/blob/custom-cursor-skills"
    )
  }

  @Test
  func resolvePathUsesCurrentDirectoryForRelativePaths() {
    let client = PathClient(
      homeDirectory: { URL(filePath: "/Users/blob", directoryHint: .isDirectory) },
      currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
    )

    expectNoDifference(
      client.resolvePath("build/skills").path,
      "/Users/blob/project/build/skills"
    )
  }
}
