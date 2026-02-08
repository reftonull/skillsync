import ArgumentParser
import Dependencies
import Foundation
import SkillSyncCore

public struct DiffCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "diff",
    abstract: "Show JSON diff between canonical and active edit copy for a skill."
  )

  @Argument(help: "Skill name.", completion: SkillNameCompletion.completion)
  public var name: String

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    let result = try DiffFeature().run(.init(name: name))

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let json = try encoder.encode(result)
    outputClient.stdout(String(decoding: json, as: UTF8.self))
  }
}
