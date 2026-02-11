import Foundation

enum SkillRelativePath {
  static func sanitize(_ path: String) -> String? {
    let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard !trimmed.isEmpty else { return nil }

    let components = trimmed.split(separator: "/", omittingEmptySubsequences: true)
    guard !components.isEmpty else { return nil }
    guard components.allSatisfy({ $0 != "." && $0 != ".." }) else { return nil }

    return components.joined(separator: "/")
  }
}
