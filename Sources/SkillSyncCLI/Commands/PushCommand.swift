import ArgumentParser
import Dependencies
import SkillSyncCore

public struct PushCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "push",
    abstract: "Commit and push ~/.skillsync to git remote."
  )

  @Option(name: [.short, .long], help: "Commit message. Defaults to 'skillsync: update skills'.")
  public var message: String?

  @Option(name: .long, help: "Remote name. Defaults to origin.")
  public var remote = "origin"

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient

    let result = try GitPushFeature().run(
      .init(remoteName: remote, message: message)
    )

    if result.committed {
      outputClient.stdout("Committed changes: \(result.commitMessage ?? "unknown")")
    } else {
      outputClient.stdout("No local changes to commit.")
    }

    outputClient.stdout("Pushed \(result.storeRoot.path) to \(result.remoteName).")
  }
}
