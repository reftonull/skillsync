import ArgumentParser
import Dependencies
import SkillSyncCore

public struct RmCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "rm",
    abstract: "Mark a skill for removal (pruned on next sync)."
  )

  @Argument(help: "Skill name.", completion: SkillNameCompletion.completion)
  public var name: String

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try RmFeature().run(.init(name: name))
    outputClient.stdout("Marked skill \(result.skillName) for removal (pending prune on next sync)")
  }
}
