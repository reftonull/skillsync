import ArgumentParser
import Foundation

enum SkillNameCompletion {
  static let completion: CompletionKind = .custom { _, _, prefix in
    skillNames(prefix: prefix)
  }

  static func skillNames(prefix: String) -> [String] {
    skillNames(in: defaultSkillsDirectory(), prefix: prefix)
  }

  static func skillNames(in skillsDirectory: URL, prefix: String) -> [String] {
    let fileManager = FileManager.default
    guard
      let children = try? fileManager.contentsOfDirectory(
        at: skillsDirectory,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else {
      return []
    }

    let normalizedPrefix = prefix.lowercased()

    return children
      .compactMap { child in
        guard
          let isDirectory = try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
          isDirectory == true
        else {
          return nil
        }

        let name = child.lastPathComponent
        if normalizedPrefix.isEmpty || name.lowercased().hasPrefix(normalizedPrefix) {
          return name
        }
        return nil
      }
      .sorted { lhs, rhs in
        lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
      }
  }

  private static func defaultSkillsDirectory(
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> URL {
    homeDirectory
      .appendingPathComponent(".skillsync", isDirectory: true)
      .appendingPathComponent("skills", isDirectory: true)
  }
}
