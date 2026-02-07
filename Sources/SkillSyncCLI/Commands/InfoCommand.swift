import ArgumentParser
import Dependencies
import SkillSyncCore

public struct InfoCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "info",
    abstract: "Print skill metadata from .meta.toml."
  )

  @Argument(help: "Skill name.")
  public var name: String

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try InfoFeature().run(.init(name: name))
    outputClient.stdout(result.formattedOutput())
  }
}
