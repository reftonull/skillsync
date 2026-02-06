import ArgumentParser
import Dependencies
import SkillSyncCore

public struct InitCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "init",
    abstract: "Initialize ~/.skillsync store structure."
  )

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try InitFeature().run()
    if result.createdConfig {
      outputClient.stdout("Initialized skillsync store at \(result.storeRoot.path)")
    } else {
      outputClient.stdout("skillsync store already initialized at \(result.storeRoot.path)")
    }
  }
}
