import Dependencies
import Foundation

public struct SaveSyncConfigFeature {
  public struct Input: Equatable, Sendable {
    public var targets: [SyncTarget]
    public var observation: ObservationSettings

    public init(
      targets: [SyncTarget],
      observation: ObservationSettings
    ) {
      self.targets = targets
      self.observation = observation
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws {
    let root = pathClient.skillsyncRoot()
    try fileSystemClient.createDirectory(root, true)
    let configURL = root.appendingPathComponent("config.toml")
    try fileSystemClient.write(Data(Self.render(input).utf8), configURL)
  }

  static func render(_ input: Input) -> String {
    var lines: [String] = []
    lines.append("[skillsync]")
    lines.append("version = \"1\"")
    lines.append("")
    lines.append("[observation]")
    lines.append("mode = \"\(input.observation.mode.rawValue)\"")
    lines.append("threshold = \(input.observation.threshold)")
    lines.append("min_invocations = \(input.observation.minInvocations)")

    for target in input.targets {
      lines.append("")
      lines.append("[[targets]]")
      lines.append("id = \"\(Self.escape(target.id))\"")
      lines.append("path = \"\(Self.escape(target.path))\"")
      lines.append("source = \"\(target.source.rawValue)\"")
    }

    return lines.joined(separator: "\n")
  }

  private static func escape(_ raw: String) -> String {
    raw.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
  }
}
