import ArgumentParser
import Dependencies
import SkillSyncCore

extension ObserveFeature.Signal: ExpressibleByArgument {}

public struct ObserveCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "observe",
    abstract: "Log an observation for a skill and update stats."
  )

  @Argument(help: "Skill name.", completion: SkillNameCompletion.completion)
  public var name: String

  @Option(name: .long, help: "Observation signal: positive or negative.")
  public var signal: ObserveFeature.Signal

  @Option(name: .long, help: "Optional observation note.")
  public var note: String?

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try ObserveFeature().run(
      .init(name: name, signal: signal, note: note)
    )
    outputClient.stdout("Logged observation for \(result.name) signal=\(result.signal.rawValue)")
  }
}
