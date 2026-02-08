import ArgumentParser
import Dependencies
import SkillSyncCore

public struct TargetListCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List configured sync targets."
  )

  @Flag(name: .long, help: "Output as JSON.")
  public var json = false

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try TargetListFeature().run()

    if json {
      outputClient.stdout(try OutputFormatting.json(result.targets))
      return
    }

    guard !result.targets.isEmpty else {
      outputClient.stdout("No targets configured.")
      return
    }

    var rows = [["ID", "PATH"]]
    for target in result.targets {
      rows.append([target.id, target.path])
    }
    for line in OutputFormatting.alignedRows(rows) {
      outputClient.stdout(line)
    }
  }
}
