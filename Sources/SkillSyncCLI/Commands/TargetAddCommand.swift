import ArgumentParser
import Dependencies
import SkillSyncCore

public struct TargetAddCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "add",
    abstract: "Add a sync target."
  )

  @Option(name: .long, help: "Known tool to add (claude-code, codex, cursor).")
  public var tool: String?

  @Option(name: .long, help: "Explicit path to add as a target.")
  public var path: String?

  @Flag(name: .long, help: "Add project-local tool targets from the current project root.")
  public var project = false

  public init() {}

  public mutating func run() async throws {
    @Dependency(\.outputClient) var outputClient

    let selectedModes =
      (self.tool == nil ? 0 : 1)
      + (self.path == nil ? 0 : 1)
      + (self.project ? 1 : 0)
    guard selectedModes == 1 else {
      throw ValidationError("Pass exactly one of --tool, --path, or --project.")
    }

    let mode: TargetAddFeature.Mode
    if let tool {
      mode = .tool(tool)
    } else if let path {
      mode = .path(path)
    } else {
      mode = .project
    }

    let result = try TargetAddFeature().run(.init(mode: mode))
    for target in result.added {
      outputClient.stdout("added target=\(target.id) path=\(target.path)")
    }
    for skipped in result.skipped {
      outputClient.stdout("skipped path=\(skipped)")
    }
  }
}
