import ArgumentParser
import Dependencies
import SkillSyncCore

public struct CommitCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "commit",
    abstract: "Commit an active skill edit into canonical storage."
  )

  @Argument(help: "Skill name.", completion: SkillNameCompletion.completion)
  public var name: String

  @Option(name: .long, help: "Reason for this commit.")
  public var reason: String

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try CommitFeature().run(.init(name: name, reason: reason))
    outputClient.stdout("Committed skill \(result.name) version=\(result.versionAfter)")
  }
}
