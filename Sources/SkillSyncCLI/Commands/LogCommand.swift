import ArgumentParser
import Dependencies
import SkillSyncCore

public struct LogCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "log",
    abstract: "Print observation history for a skill."
  )

  @Argument(help: "Skill name.")
  public var name: String

  @Flag(name: .long, help: "Print one-line summary instead of full history.")
  public var summary = false

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try LogFeature().run(
      .init(name: name, summary: summary)
    )
    for line in result.lines {
      outputClient.stdout(line)
    }
  }
}
