import CustomDump
import Dependencies
import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct SkillContentHashFeatureTests {
  @Test
  func isDeterministicAcrossFileCreationOrder() throws {
    let first = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let second = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )

    let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/pdf", directoryHint: .isDirectory)
    for fileSystem in [first, second] {
      try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
      try fileSystem.createDirectory(
        at: skillRoot.appendingPathComponent("scripts", isDirectory: true),
        withIntermediateDirectories: true
      )
    }

    try first.write(Data("B".utf8), to: skillRoot.appendingPathComponent("scripts/b.swift"))
    try first.write(Data("A".utf8), to: skillRoot.appendingPathComponent("scripts/a.swift"))
    try first.write(Data("# PDF\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))

    try second.write(Data("# PDF\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))
    try second.write(Data("A".utf8), to: skillRoot.appendingPathComponent("scripts/a.swift"))
    try second.write(Data("B".utf8), to: skillRoot.appendingPathComponent("scripts/b.swift"))

    let firstHash = try withDependencies {
      $0.fileSystemClient = first.client
    } operation: {
      try SkillContentHashFeature().run(skillDirectory: skillRoot)
    }

    let secondHash = try withDependencies {
      $0.fileSystemClient = second.client
    } operation: {
      try SkillContentHashFeature().run(skillDirectory: skillRoot)
    }

    expectNoDifference(firstHash, secondHash)
  }

  @Test
  func excludesMetaFileFromHash() throws {
    let fileSystem = InMemoryFileSystem(
      homeDirectoryForCurrentUser: URL(filePath: "/Users/blob", directoryHint: .isDirectory)
    )
    let skillRoot = URL(filePath: "/Users/blob/.skillsync/skills/pdf", directoryHint: .isDirectory)
    try fileSystem.createDirectory(at: skillRoot, withIntermediateDirectories: true)
    try fileSystem.write(Data("# PDF\n".utf8), to: skillRoot.appendingPathComponent("SKILL.md"))
    try fileSystem.write(Data("v1".utf8), to: skillRoot.appendingPathComponent(".meta.toml"))

    let firstHash = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SkillContentHashFeature().run(skillDirectory: skillRoot)
    }

    try fileSystem.write(Data("v2".utf8), to: skillRoot.appendingPathComponent(".meta.toml"))

    let secondHash = try withDependencies {
      $0.fileSystemClient = fileSystem.client
    } operation: {
      try SkillContentHashFeature().run(skillDirectory: skillRoot)
    }

    expectNoDifference(firstHash, secondHash)
  }
}
