import ArgumentParser
import Dependencies
import SkillSyncCore

public struct LsCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "ls",
    abstract: "List skills with lifecycle state and summary stats."
  )

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try LsFeature().run()

    guard !result.skills.isEmpty else {
      outputClient.stdout("No skills found.")
      return
    }

    for skill in result.skills {
      outputClient.stdout(
        "\(skill.name) state=\(skill.state) total=\(skill.totalInvocations) positive=\(skill.positive) negative=\(skill.negative)"
      )
    }
  }
}
