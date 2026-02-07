import ArgumentParser
import Dependencies
import SkillSyncCore

public struct SyncCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "sync",
    abstract: "Sync all skills to configured targets."
  )

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    @Dependency(\.pathClient) var pathClient
    let config = try LoadSyncConfigFeature().run()
    guard !config.targets.isEmpty else {
      throw ValidationError("No targets configured. Use `skillsync target add ...`.")
    }

    let syncResult = try SyncRenderFeature().run(
      .init(
        targets: config.targets,
        observation: config.observation
      )
    )

    for target in syncResult.targets {
      let resolvedPath = pathClient.resolvePath(target.target.path).path
      let configuredPathSuffix =
        target.target.path == resolvedPath
        ? ""
        : " configured_path=\(target.target.path)"
      if let error = target.error {
        outputClient.stdout(
          """
          target=\(target.target.id) path=\(resolvedPath) status=failed error="\(error)"\(configuredPathSuffix)
          """
        )
      } else {
        outputClient.stdout(
          """
          target=\(target.target.id) path=\(resolvedPath) status=ok skills=\(target.syncedSkills)\(configuredPathSuffix)
          """
        )
      }
    }

    if !syncResult.allSucceeded {
      throw ExitCode(1)
    }
  }
}
