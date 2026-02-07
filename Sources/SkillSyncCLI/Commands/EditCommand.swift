import ArgumentParser
import Dependencies
import SkillSyncCore

public struct EditCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "edit",
    abstract: "Acquire a skill edit lock and prepare an editable working copy."
  )

  @Argument(help: "Skill name.")
  public var name: String

  @Flag(name: .long, help: "Discard existing edit copy and recopy from canonical skill.")
  public var reset = false

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try EditFeature().run(.init(name: name, reset: reset))
    outputClient.stdout("Editing skill \(result.name) at \(result.editRoot.path)")
  }
}
