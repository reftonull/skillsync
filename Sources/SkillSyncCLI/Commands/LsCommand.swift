import ArgumentParser
import Dependencies
import SkillSyncCore

public struct LsCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "ls",
    abstract: "List skills with lifecycle state and summary stats."
  )

  @Flag(name: .long, help: "Output as JSON.")
  public var json = false

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try LsFeature().run()

    if json {
      outputClient.stdout(try OutputFormatting.json(result))
      return
    }

    guard !result.skills.isEmpty else {
      outputClient.stdout("No skills found.")
      return
    }

    var rows = [["NAME", "STATE", "OBSERVATIONS"]]
    for skill in result.skills {
      let observations: String
      if skill.totalInvocations == 0 {
        observations = "0"
      } else {
        observations = "\(skill.totalInvocations) (\(skill.positive)+, \(skill.negative)-)"
      }
      rows.append([skill.name, skill.state, observations])
    }

    for line in OutputFormatting.alignedRows(rows) {
      outputClient.stdout(line)
    }
  }
}
