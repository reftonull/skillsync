import ArgumentParser
import Dependencies
import SkillSyncCore

public struct AddCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "add",
    abstract: "Import an existing skill directory into the canonical store."
  )

  @Argument(help: "Path to the skill directory to import.")
  public var path: String

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try AddFeature().run(.init(sourcePath: path))
    outputClient.stdout("Imported skill \(result.skillName) to \(result.skillRoot.path)")
  }
}
