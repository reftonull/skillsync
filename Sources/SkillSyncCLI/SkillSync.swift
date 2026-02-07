import ArgumentParser

public struct SkillSync: AsyncParsableCommand {
  public static let version = "0.1.0"

  public static let configuration = CommandConfiguration(
    commandName: "skillsync",
    abstract: "Manage AI-agent skills from one canonical local store.",
    version: version,
    subcommands: [
      AbortCommand.self,
      AddCommand.self,
      CommitCommand.self,
      DiffCommand.self,
      EditCommand.self,
      ExportCommand.self,
      InfoCommand.self,
      InitCommand.self,
      LsCommand.self,
      NewCommand.self,
      ObserveCommand.self,
      RmCommand.self,
      SyncCommand.self,
      TargetCommand.self,
      VersionCommand.self,
    ]
  )

  public init() {}
}
