import ArgumentParser
import Dependencies
import SkillSyncCore

public struct NewCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "new",
    abstract: "Create a new skill scaffold in the canonical store."
  )

  @Argument(help: "Skill name.")
  public var name: String

  @Option(name: .long, help: "Optional one-line skill description.")
  public var description: String?

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try NewFeature().run(
      .init(name: self.name, description: self.description)
    )
    outputClient.stdout("Created skill \(name) at \(result.skillRoot.path)")
  }
}
