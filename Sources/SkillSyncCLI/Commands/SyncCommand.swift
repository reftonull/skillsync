import ArgumentParser
import Dependencies
import SkillSyncCore

public struct SyncCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "sync",
    abstract: "Resolve sync destinations for tools and paths."
  )

  @Option(name: .long, help: "Known tool name to sync (repeatable).")
  public var tool: [String] = []

  @Option(name: .long, help: "Explicit path to sync to (repeatable).")
  public var path: [String] = []

  @Flag(name: .long, help: "Resolve project-local tool paths by finding the project root.")
  public var project = false

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let configuredTools = try LoadSyncConfigFeature().run().configuredTools
    let result = try ResolveSyncDestinationsFeature().run(
      .init(
        tools: self.tool,
        paths: self.path,
        project: self.project,
        configuredTools: configuredTools
      )
    )

    for destination in result.destinations {
      outputClient.stdout("destination=\(destination.id) path=\(destination.path.path)")
    }
  }
}
