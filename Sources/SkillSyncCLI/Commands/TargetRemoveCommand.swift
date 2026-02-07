import ArgumentParser
import Dependencies
import SkillSyncCore

public struct TargetRemoveCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "remove",
    abstract: "Remove a sync target by id."
  )

  @Argument(help: "Target id.")
  public var id: String

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try TargetRemoveFeature().run(.init(id: id))
    outputClient.stdout("removed target=\(result.removed.id) path=\(result.removed.path)")
  }
}
