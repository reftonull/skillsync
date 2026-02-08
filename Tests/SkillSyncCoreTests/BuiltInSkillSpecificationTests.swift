import Foundation
import Testing

@testable import SkillSyncCore

@Suite
struct BuiltInSkillSpecificationTests {
  @Test
  func seededSkillsIncludeSpecAwareGuidance() throws {
    for skill in BuiltInSkill.seeded() {
      let content = try #require(skill.files["SKILL.md"])
      let markdown = String(decoding: content, as: UTF8.self)
      let parsed = try parseFrontmatter(from: markdown)

      let name = try #require(parsed["name"])
      let description = try #require(parsed["description"])
      let compatibility = try #require(parsed["compatibility"])

      #expect(name == skill.name)
      #expect(!description.isEmpty)
      #expect(!compatibility.isEmpty)
      #expect(markdown.contains("## Common edge cases"))
      #expect(markdown.contains("skillsync"))
    }
  }

  private func parseFrontmatter(from markdown: String) throws -> [String: String] {
    let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    guard lines.first == "---" else {
      Issue.record("Missing frontmatter start delimiter")
      throw FrontmatterError.missingDelimiter
    }

    guard let endIndex = lines.dropFirst().firstIndex(of: "---") else {
      Issue.record("Missing frontmatter end delimiter")
      throw FrontmatterError.missingDelimiter
    }

    var fields: [String: String] = [:]
    for line in lines[1..<endIndex] {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard
        !trimmed.isEmpty,
        !trimmed.hasPrefix("#"),
        let separator = trimmed.firstIndex(of: ":")
      else {
        continue
      }

      let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
      var value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
      if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
        value.removeFirst()
        value.removeLast()
      }
      if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
        value.removeFirst()
        value.removeLast()
      }
      fields[key] = value
    }

    return fields
  }
}

private enum FrontmatterError: Error {
  case missingDelimiter
}
