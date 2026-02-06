import ArgumentParser
import Dependencies
import SkillSyncCore

public struct VersionCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "version",
    abstract: "Print the skillsync CLI version."
  )

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    outputClient.stdout("skillsync \(SkillSync.version)")
  }
}
