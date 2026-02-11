import ArgumentParser
import Dependencies
import SkillSyncCore

public struct AddCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "add",
    abstract: "Import a local skill, or import from GitHub."
  )

  @Flag(name: .long, help: "Skip confirmation when importing from GitHub.")
  public var force = false

  @Argument(help: "Local path to import, or `github`.")
  public var source: String

  @Argument(help: "When source is `github`: <owner/repo>.")
  public var repo: String?

  @Argument(help: "When source is `github`: <skill-path>.")
  public var skillPath: String?

  @Argument(help: "When source is `github`: optional <ref>. Defaults to main.")
  public var ref: String?

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    @Dependency(\.confirmationClient) var confirmationClient

    let input: AddFeature.Input
    if source == "github" {
      guard let repo, let skillPath else {
        throw ValidationError("Usage: skillsync add github <owner/repo> <skill-path> [<ref>]")
      }

      if !force {
        let confirmed = confirmationClient.confirm(
          "Importing from GitHub may include untrusted content. Continue? [y/N]"
        )
        guard confirmed else {
          outputClient.stdout("Cancelled GitHub import.")
          return
        }
      }

      input = try .init(githubSource: GitHubSkillSource(repo: repo, skillPath: skillPath, ref: ref ?? "main"))
    } else {
      guard !force else {
        throw ValidationError("`--force` is only supported for `skillsync add github ...`.")
      }
      guard repo == nil, skillPath == nil, ref == nil else {
        throw ValidationError("Usage: skillsync add <path>")
      }
      input = .init(sourcePath: source)
    }

    let result = try AddFeature().run(input)
    outputClient.stdout("Imported skill \(result.skillName) to \(result.skillRoot.path)")
    outputClient.stdout("Run `skillsync sync` to apply changes to configured targets.")
  }
}
