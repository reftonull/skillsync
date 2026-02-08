import ArgumentParser
import Dependencies
import SkillSyncCore

public struct AbortCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "abort",
    abstract: "Abort an active skill edit and release its lock."
  )

  @Argument(help: "Skill name.", completion: SkillNameCompletion.completion)
  public var name: String

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try AbortFeature().run(.init(name: name))
    outputClient.stdout("Aborted edit for skill \(result.name)")
  }
}
