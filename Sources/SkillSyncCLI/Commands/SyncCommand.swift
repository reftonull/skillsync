import ArgumentParser
import Dependencies
import SkillSyncCore

public struct SyncCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "sync",
    abstract: "Sync all skills to configured targets."
  )

  @Flag(name: .long, help: "Output as JSON.")
  public var json = false

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

    if json {
      outputClient.stdout(try OutputFormatting.json(syncResult))
    } else {
      var rows: [[String]] = []
      for target in syncResult.targets {
        let status = "[\(target.status.rawValue)]"
        let resolvedPath = pathClient.resolvePath(target.target.path).path
        let detail = if target.status == .ok {
          "(\(target.syncedSkills) skills)"
        } else {
          "Error: \(target.error ?? "unknown")"
        }
        rows.append([status, target.target.id, resolvedPath, detail])
      }
      for line in OutputFormatting.alignedRows(rows) {
        outputClient.stdout(line)
      }
    }

    if !syncResult.allSucceeded {
      throw ExitCode(1)
    }
  }
}
