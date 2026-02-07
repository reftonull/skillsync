import ArgumentParser
import Dependencies
import SkillSyncCore

public struct TargetListCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List configured sync targets."
  )

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try TargetListFeature().run()
    for target in result.targets {
      outputClient.stdout("\(target.id) \(target.path)")
    }
  }
}
