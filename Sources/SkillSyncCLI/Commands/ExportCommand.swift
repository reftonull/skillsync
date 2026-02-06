import ArgumentParser
import Dependencies
import SkillSyncCore

public struct ExportCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "export",
    abstract: "Copy a skill out of the canonical store."
  )

  @Argument(help: "Skill name.")
  public var name: String

  @Argument(help: "Destination path.")
  public var path: String

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try ExportFeature().run(
      .init(name: name, destinationPath: path)
    )
    outputClient.stdout("Exported skill \(result.skillName) to \(result.destination.path)")
  }
}
