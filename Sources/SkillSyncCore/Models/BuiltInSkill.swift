import Foundation

public struct BuiltInSkill: Equatable, Sendable {
  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case missingResourcesRoot
    case missingTemplate(name: String)
    case noTemplateFiles(name: String)

    public var description: String {
      switch self {
      case .missingResourcesRoot:
        return "Missing built-in skill resources root."
      case let .missingTemplate(name):
        return "Missing built-in template for '\(name)'."
      case let .noTemplateFiles(name):
        return "Built-in template for '\(name)' does not contain files."
      }
    }
  }

  public var name: String
  public var files: [String: Data]

  public init(name: String, files: [String: Data]) {
    self.name = name
    self.files = files
  }
}

public extension BuiltInSkill {
  static let seededNames = [
    "skillsync-new",
    "skillsync-check",
    "skillsync-refine",
  ]

  static func seeded() throws -> [BuiltInSkill] {
    guard let resourcesRoot = Bundle.module.resourceURL?.appendingPathComponent("BuiltInSkills", isDirectory: true)
    else {
      throw Error.missingResourcesRoot
    }

    return try seededNames.map { name in
      let templateDirectory = resourcesRoot.appendingPathComponent(name, isDirectory: true)
      var isDirectory = ObjCBool(false)
      guard FileManager.default.fileExists(atPath: templateDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue
      else {
        throw Error.missingTemplate(name: name)
      }
      guard let enumerator = FileManager.default.enumerator(
        at: templateDirectory,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: []
      ) else {
        throw Error.missingTemplate(name: name)
      }

      let templateRootPath = templateDirectory.standardizedFileURL.path
      var files: [String: Data] = [:]
      for case let fileURL as URL in enumerator {
        let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory != true else { continue }
        let fullPath = fileURL.standardizedFileURL.path
        guard fullPath.hasPrefix(templateRootPath + "/") else { continue }
        let relativePath = String(fullPath.dropFirst(templateRootPath.count + 1))
        files[relativePath] = try Data(contentsOf: fileURL)
      }
      guard !files.isEmpty else {
        throw Error.noTemplateFiles(name: name)
      }
      return BuiltInSkill(name: name, files: files)
    }
  }
}
