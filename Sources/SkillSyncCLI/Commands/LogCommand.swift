import ArgumentParser
import Dependencies
import SkillSyncCore

public struct LogCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "log",
    abstract: "Print observation history for a skill."
  )

  @Argument(help: "Skill name.")
  public var name: String

  @Flag(name: .long, help: "Print one-line summary instead of full history.")
  public var summary = false

  @Flag(name: .long, help: "Output as JSON.")
  public var json = false

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try LogFeature().run(
      .init(name: name, summary: summary)
    )

    if json {
      outputClient.stdout(try OutputFormatting.json(result))
      return
    }

    if summary {
      for line in result.lines {
        outputClient.stdout(line)
      }
      return
    }

    for record in result.records {
      let prefix = record.signal == .positive ? "+" : "-"
      if let note = record.note {
        outputClient.stdout("\(prefix)  \(record.timestamp)  \"\(note)\"")
      } else {
        outputClient.stdout("\(prefix)  \(record.timestamp)")
      }
    }
  }
}
