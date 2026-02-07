import Dependencies
import Foundation

public struct SyncRenderFeature {
  public struct Input: Equatable, Sendable {
    public var targets: [SyncTarget]
    public var observation: ObservationSettings

    public init(targets: [SyncTarget], observation: ObservationSettings) {
      self.targets = targets
      self.observation = observation
    }
  }

  public struct Result: Equatable, Sendable {
    public var targets: [TargetResult]
    public var allSucceeded: Bool {
      targets.allSatisfy { $0.status == .ok }
    }

    public init(targets: [TargetResult]) {
      self.targets = targets
    }
  }

  public struct TargetResult: Equatable, Sendable {
    public enum Status: String, Equatable, Sendable {
      case ok
      case failed
    }

    public var target: SyncTarget
    public var status: Status
    public var syncedSkills: Int
    public var error: String?

    public init(
      target: SyncTarget,
      status: Status,
      syncedSkills: Int,
      error: String?
    ) {
      self.target = target
      self.status = status
      self.syncedSkills = syncedSkills
      self.error = error
    }
  }

  enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case destinationEntryConflict(path: String)

    var description: String {
      switch self {
      case let .destinationEntryConflict(path):
        return "Destination contains unmanaged entry at \(path)"
      }
    }
  }

  struct SkillRecord: Equatable, Sendable {
    var name: String
    var root: URL
    var state: String
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let skills = try self.loadSkills()
    let activeSkills = skills.filter { $0.state != "pending_remove" }
    let pendingRemoveSkills = Set(skills.filter { $0.state == "pending_remove" }.map(\.name))
    let renderedRoot = pathClient.skillsyncRoot().appendingPathComponent("rendered", isDirectory: true)
    try fileSystemClient.createDirectory(renderedRoot, true)

    var targetResults: [TargetResult] = []
    for target in input.targets {
      do {
        let synced = try self.syncTarget(
          target,
          activeSkills: activeSkills,
          pendingRemoveSkills: pendingRemoveSkills,
          observation: input.observation,
          renderedRoot: renderedRoot
        )
        targetResults.append(
          TargetResult(target: target, status: .ok, syncedSkills: synced, error: nil)
        )
      } catch {
        targetResults.append(
          TargetResult(
            target: target,
            status: .failed,
            syncedSkills: 0,
            error: String(describing: error)
          )
        )
      }
    }

    if targetResults.allSatisfy({ $0.status == .ok }) {
      try self.prunePendingFromCanonicalStore(pendingRemoveSkills)
    }

    return Result(targets: targetResults)
  }

  private func syncTarget(
    _ target: SyncTarget,
    activeSkills: [SkillRecord],
    pendingRemoveSkills: Set<String>,
    observation: ObservationSettings,
    renderedRoot: URL
  ) throws -> Int {
    let targetPath = pathClient.resolvePath(target.path)
    try fileSystemClient.createDirectory(targetPath, true)
    let renderedDestinationRoot = renderedRoot.appendingPathComponent(target.id, isDirectory: true)
    try fileSystemClient.createDirectory(renderedDestinationRoot, true)

    var syncedSkills = 0
    for skill in activeSkills.sorted(by: { $0.name < $1.name }) {
      let renderedSkillRoot = renderedDestinationRoot.appendingPathComponent(skill.name, isDirectory: true)
      if fileSystemClient.fileExists(renderedSkillRoot.path) {
        try fileSystemClient.removeItem(renderedSkillRoot)
      }
      try CopyDirectoryFeature().run(
        from: skill.root,
        to: renderedSkillRoot,
        excluding: [".meta.toml"]
      )
      try self.injectObservationFooterIfNeeded(
        skillName: skill.name,
        renderedSkillRoot: renderedSkillRoot,
        observation: observation
      )
      try self.installManagedLink(
        skillName: skill.name,
        destination: targetPath,
        renderedSkillRoot: renderedSkillRoot,
        renderedRoot: renderedRoot
      )
      syncedSkills += 1
    }

    for pendingSkill in pendingRemoveSkills {
      let renderedSkillRoot = renderedDestinationRoot.appendingPathComponent(pendingSkill, isDirectory: true)
      if fileSystemClient.fileExists(renderedSkillRoot.path) {
        try fileSystemClient.removeItem(renderedSkillRoot)
      }
    }

    let activeNames = Set(activeSkills.map(\.name))
    try self.pruneDestinationLinks(
      destination: targetPath,
      activeSkillNames: activeNames,
      renderedRoot: renderedRoot
    )

    return syncedSkills
  }

  private func installManagedLink(
    skillName: String,
    destination: URL,
    renderedSkillRoot: URL,
    renderedRoot: URL
  ) throws {
    let link = destination.appendingPathComponent(skillName, isDirectory: false)
    if fileSystemClient.fileExists(link.path) {
      if fileSystemClient.isSymbolicLink(link.path) {
        let existingTarget = try fileSystemClient.destinationOfSymbolicLink(link).standardizedFileURL
        if existingTarget.path.hasPrefix(renderedRoot.standardizedFileURL.path + "/") {
          try fileSystemClient.removeItem(link)
        } else {
          throw Error.destinationEntryConflict(path: link.path)
        }
      } else {
        throw Error.destinationEntryConflict(path: link.path)
      }
    }

    try fileSystemClient.createSymbolicLink(link, renderedSkillRoot)
  }

  private func pruneDestinationLinks(
    destination: URL,
    activeSkillNames: Set<String>,
    renderedRoot: URL
  ) throws {
    let children = try fileSystemClient.contentsOfDirectory(destination)
    for child in children {
      guard fileSystemClient.isSymbolicLink(child.path) else { continue }
      let target = try fileSystemClient.destinationOfSymbolicLink(child).standardizedFileURL
      guard target.path.hasPrefix(renderedRoot.standardizedFileURL.path + "/") else { continue }
      if !activeSkillNames.contains(child.lastPathComponent) {
        try fileSystemClient.removeItem(child)
      }
    }
  }

  private func injectObservationFooterIfNeeded(
    skillName _: String,
    renderedSkillRoot: URL,
    observation: ObservationSettings
  ) throws {
    guard observation.mode != .off else { return }

    let markdownPath = renderedSkillRoot.appendingPathComponent("SKILL.md")
    guard fileSystemClient.fileExists(markdownPath.path) else { return }

    let content = try fileSystemClient.data(markdownPath)
    guard var markdown = String(data: content, encoding: .utf8) else { return }

    markdown = Self.removingObservationFooter(from: markdown)
    let footer = Self.observationFooter(mode: observation.mode)
    if !markdown.hasSuffix("\n") {
      markdown.append("\n")
    }
    markdown.append("\n")
    markdown.append(footer)
    markdown.append("\n")

    try fileSystemClient.write(Data(markdown.utf8), markdownPath)
  }

  private func prunePendingFromCanonicalStore(_ pendingRemoveSkills: Set<String>) throws {
    guard !pendingRemoveSkills.isEmpty else { return }
    let skillsRoot = pathClient.skillsyncRoot().appendingPathComponent("skills", isDirectory: true)
    for skill in pendingRemoveSkills {
      let skillRoot = skillsRoot.appendingPathComponent(skill, isDirectory: true)
      if fileSystemClient.fileExists(skillRoot.path) {
        try fileSystemClient.removeItem(skillRoot)
      }
    }
  }

  private func loadSkills() throws -> [SkillRecord] {
    let skillsRoot = pathClient.skillsyncRoot().appendingPathComponent("skills", isDirectory: true)
    guard fileSystemClient.fileExists(skillsRoot.path), fileSystemClient.isDirectory(skillsRoot.path) else {
      return []
    }

    let skillDirectories = try fileSystemClient.contentsOfDirectory(skillsRoot)
      .filter { fileSystemClient.isDirectory($0.path) }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    return try skillDirectories.map { directory in
      SkillRecord(
        name: directory.lastPathComponent,
        root: directory,
        state: try self.skillState(for: directory)
      )
    }
  }

  private func skillState(for skillDirectory: URL) throws -> String {
    let metaPath = skillDirectory.appendingPathComponent(".meta.toml")
    let document = try UpdateMetaFeature().read(metaURL: metaPath)
    return document.string(section: "skill", key: "state") ?? "active"
  }

  private static func removingObservationFooter(from text: String) -> String {
    let startMarker = "<!-- skillsync:observation:start -->"
    let endMarker = "<!-- skillsync:observation:end -->"
    guard let start = text.range(of: startMarker) else { return text }
    guard let end = text.range(of: endMarker, range: start.upperBound..<text.endIndex) else {
      return text
    }
    var output = text
    output.removeSubrange(start.lowerBound..<end.upperBound)
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func observationFooter(mode: ObservationMode) -> String {
    switch mode {
    case .off:
      return ""
    case .on:
      return """
      <!-- skillsync:observation:start -->
      ---
      After using this skill, run: skillsync observe <skill-name> --signal positive|negative [--note "..."]
      <!-- skillsync:observation:end -->
      """
    }
  }
}
