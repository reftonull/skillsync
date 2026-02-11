import ArgumentParser
import Dependencies
import SkillSyncCore

public struct UpdateCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "update",
    abstract: "Update a GitHub-managed skill."
  )

  @Argument(help: "Skill name.", completion: SkillNameCompletion.completion)
  public var name: String

  @Flag(name: .long, help: "Overwrite local divergence with upstream content.")
  public var force = false

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient

    let result = try UpdateFeature().run(.init(name: name, force: force))
    if result.updated {
      outputClient.stdout("Updated skill \(result.name) in \(result.skillRoot.path)")
      outputClient.stdout("Run `skillsync sync` to apply changes to configured targets.")
    } else {
      outputClient.stdout("Skill \(result.name) is already up to date.")
    }
  }
}
