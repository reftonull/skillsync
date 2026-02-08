import Foundation

public struct BuiltInSkill: Equatable, Sendable {
  public var name: String
  public var files: [String: Data]

  public init(name: String, files: [String: Data]) {
    self.name = name
    self.files = files
  }
}

public extension BuiltInSkill {
  private static let embeddedSkills: [(name: String, bytes: [UInt8])] = [
    ("skillsync-new", PackageResources.skillsync_new_md),
    ("skillsync-check", PackageResources.skillsync_check_md),
    ("skillsync-refine", PackageResources.skillsync_refine_md),
  ]

  static let seededNames = embeddedSkills.map(\.name)

  static func seeded() -> [BuiltInSkill] {
    embeddedSkills.map { name, bytes in
      BuiltInSkill(name: name, files: ["SKILL.md": Data(bytes)])
    }
  }
}
