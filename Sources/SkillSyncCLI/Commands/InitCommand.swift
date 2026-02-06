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
    outputClient.stdout("Scaffold only: 'skillsync init' is not implemented yet.")
  }
}
