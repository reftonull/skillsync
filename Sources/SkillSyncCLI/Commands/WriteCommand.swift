import ArgumentParser
import Dependencies
import SkillSyncCore

public struct WriteCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "write",
    abstract: "Write a file into a skill from a source file."
  )

  @Argument(help: "Skill name.")
  public var name: String

  @Option(name: .long, help: "Destination file path relative to the skill root.")
  public var file: String

  @Option(name: .long, help: "Source file path.")
  public var from: String

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try WriteFeature().run(
      .init(
        skillName: name,
        destinationRelativePath: file,
        sourcePath: from
      )
    )
    outputClient.stdout("Updated skill \(name) file \(result.destinationPath)")
  }
}
