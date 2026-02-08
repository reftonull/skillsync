import ArgumentParser
import Dependencies
import Foundation
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

      let storeRoot = pathClient.skillsyncRoot()
      if syncResult.allSucceeded, shouldSuggestPush(storeRoot: storeRoot) {
        outputClient.stdout("Tip: local skillsync changes are not on remote yet. Run: skillsync push")
      }
    }

    if !syncResult.allSucceeded {
      throw ExitCode(1)
    }
  }

  private func shouldSuggestPush(storeRoot: URL) -> Bool {
    @Dependency(\.fileSystemClient) var fileSystemClient
    @Dependency(\.gitClient) var gitClient

    let gitDirectory = storeRoot.appendingPathComponent(".git", isDirectory: true)
    guard fileSystemClient.fileExists(gitDirectory.path), fileSystemClient.isDirectory(gitDirectory.path) else {
      return false
    }

    guard
      let upstream = try? gitClient.run(storeRoot, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"]),
      upstream.succeeded
    else {
      return false
    }

    if
      let status = try? gitClient.run(storeRoot, ["status", "--porcelain"]),
      status.succeeded,
      !status.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    {
      return true
    }

    if
      let ahead = try? gitClient.run(storeRoot, ["rev-list", "--count", "@{u}..HEAD"]),
      ahead.succeeded,
      let commitsAhead = Int(ahead.stdout.trimmingCharacters(in: .whitespacesAndNewlines)),
      commitsAhead > 0
    {
      return true
    }

    return false
  }
}
