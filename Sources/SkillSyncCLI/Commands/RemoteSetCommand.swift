import ArgumentParser
import Dependencies
import SkillSyncCore

public struct RemoteSetCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "set",
    abstract: "Set git remote URL for ~/.skillsync."
  )

  @Argument(help: "Git remote URL.")
  public var url: String

  @Option(name: .long, help: "Remote name. Defaults to origin.")
  public var name = "origin"

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient

    let result = try GitRemoteSetFeature().run(
      .init(remoteName: name, remoteURL: url)
    )

    if result.initializedRepository {
      outputClient.stdout("Initialized git repository at \(result.storeRoot.path)")
    }

    switch result.action {
    case .added:
      outputClient.stdout("Added remote \(result.remoteName) -> \(result.remoteURL)")
    case .updated:
      outputClient.stdout("Updated remote \(result.remoteName) -> \(result.remoteURL)")
    }
  }
}
