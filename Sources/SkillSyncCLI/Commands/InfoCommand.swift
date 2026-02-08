import ArgumentParser
import Dependencies
import SkillSyncCore

public struct InfoCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "info",
    abstract: "Print skill metadata from .meta.toml."
  )

  @Argument(help: "Skill name.", completion: SkillNameCompletion.completion)
  public var name: String

  @Flag(name: .long, help: "Output as JSON.")
  public var json = false

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try InfoFeature().run(.init(name: name))

    if json {
      outputClient.stdout(try OutputFormatting.json(result))
      return
    }

    let rows = [
      ("Skill", result.name),
      ("Version", String(result.version)),
      ("State", result.state),
      ("Source", Self.displaySource(result.source)),
      ("Created", result.created ?? "unknown"),
      ("Content hash", result.contentHash ?? "unknown"),
      ("Observations", "\(result.totalInvocations) (\(result.positive) positive, \(result.negative) negative)"),
    ]

    let labelWidth = rows.map { $0.0.count }.max() ?? 0
    for row in rows {
      let padding = String(repeating: " ", count: max(0, labelWidth - row.0.count))
      outputClient.stdout("\(row.0):\(padding) \(row.1)")
    }
  }

  private static func displaySource(_ source: String?) -> String {
    guard let source else { return "unknown" }
    if source == "hand-authored" {
      return "user"
    }
    return source
  }
}
