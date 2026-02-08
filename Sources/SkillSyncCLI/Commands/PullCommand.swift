import ArgumentParser
import Dependencies
import SkillSyncCore

public struct PullCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "pull",
    abstract: "Pull ~/.skillsync from git and run sync."
  )

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient
    @Dependency(\.pathClient) var pathClient

    let result = try GitPullFeature().run()
    outputClient.stdout("Pulled latest changes into \(result.storeRoot.path)")

    guard let syncResult = result.syncResult else {
      outputClient.stdout("No targets configured. Skipped sync.")
      return
    }

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

    if !syncResult.allSucceeded {
      throw ExitCode(1)
    }
  }
}
