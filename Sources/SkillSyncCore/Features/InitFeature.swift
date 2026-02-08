import Dependencies
import Foundation

public struct InitFeature {
  public struct Result: Equatable, Sendable {
    public var storeRoot: URL
    public var createdConfig: Bool

    public init(storeRoot: URL, createdConfig: Bool) {
      self.storeRoot = storeRoot
      self.createdConfig = createdConfig
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient
  @Dependency(\.builtInSkillsClient) var builtInSkillsClient
  @Dependency(\.date.now) var now

  public init() {}

  public func run() throws -> Result {
    let storeRoot = pathClient.skillsyncRoot()
    let skills = storeRoot.appendingPathComponent("skills", isDirectory: true)
    let rendered = storeRoot.appendingPathComponent("rendered", isDirectory: true)
    let logs = storeRoot.appendingPathComponent("logs", isDirectory: true)
    let config = storeRoot.appendingPathComponent("config.toml")

    try fileSystemClient.createDirectory(storeRoot, true)
    try fileSystemClient.createDirectory(skills, true)
    try fileSystemClient.createDirectory(rendered, true)
    try fileSystemClient.createDirectory(logs, true)
    try self.seedBuiltInSkills(skillsRoot: skills)

    let createdConfig = !fileSystemClient.fileExists(config.path)
    if createdConfig {
      try fileSystemClient.write(Data(Self.defaultConfig.utf8), config)
    }

    let gitignore = storeRoot.appendingPathComponent(".gitignore")
    try self.ensureDefaultGitignoreEntries(at: gitignore)

    return Result(storeRoot: storeRoot, createdConfig: createdConfig)
  }

  static let defaultGitignore = """
    config.toml
    rendered/
    logs/
    """

  static let defaultConfig = """
    [skillsync]
    version = "1"

    [observation]
    mode = "on"
    """

  private func seedBuiltInSkills(skillsRoot: URL) throws {
    for skill in try builtInSkillsClient.load() {
      let skillRoot = skillsRoot.appendingPathComponent(skill.name, isDirectory: true)
      try fileSystemClient.createDirectory(skillRoot, true)
      for relativePath in skill.files.keys.sorted() {
        let destinationURL = skillRoot.appendingPathComponent(relativePath)
        if fileSystemClient.fileExists(destinationURL.path) {
          continue
        }
        guard let data = skill.files[relativePath] else { continue }
        try fileSystemClient.createDirectory(destinationURL.deletingLastPathComponent(), true)
        try fileSystemClient.write(data, destinationURL)
      }

      let metaURL = skillRoot.appendingPathComponent(".meta.toml")
      if !fileSystemClient.fileExists(metaURL.path) {
        let contentHash = try SkillContentHashFeature().run(skillDirectory: skillRoot)
        let meta = Self.builtInMetaToml(createdAt: Self.formatDate(now), contentHash: contentHash)
        try fileSystemClient.write(Data(meta.utf8), metaURL)
      }
    }
  }

  private func ensureDefaultGitignoreEntries(at gitignoreURL: URL) throws {
    let requiredEntries = Self.defaultGitignore
      .split(separator: "\n", omittingEmptySubsequences: true)
      .map { String($0) }

    if !fileSystemClient.fileExists(gitignoreURL.path) {
      try fileSystemClient.write(Data(Self.defaultGitignore.utf8), gitignoreURL)
      return
    }

    let existing = String(decoding: try fileSystemClient.data(gitignoreURL), as: UTF8.self)
    let existingLines = existing
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { String($0) }

    let missingEntries = requiredEntries.filter { !existingLines.contains($0) }
    var merged = existingLines
    if !missingEntries.isEmpty {
      if !merged.isEmpty, !merged.last!.isEmpty {
        merged.append("")
      }
      merged.append(contentsOf: missingEntries)
    }

    let normalized = merged.joined(separator: "\n")
    let output = normalized.hasSuffix("\n") ? normalized : normalized + "\n"
    if output != existing {
      try fileSystemClient.write(Data(output.utf8), gitignoreURL)
    }
  }

  private static func builtInMetaToml(createdAt: String, contentHash: String) -> String {
    """
    [skill]
    created = "\(createdAt)"
    source = "built-in"
    version = 1
    content-hash = "\(contentHash)"
    state = "active"
    """
  }

  private static func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
  }
}
