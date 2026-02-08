import ArgumentParser

public struct SkillSync: AsyncParsableCommand {
  public static let version = "0.1.0"

  public static let configuration = CommandConfiguration(
    commandName: "skillsync",
    abstract: "Manage AI-agent skills from one canonical local store.",
    version: version,
    subcommands: [
      AddCommand.self,
      ExportCommand.self,
      InfoCommand.self,
      InitCommand.self,
      LogCommand.self,
      LsCommand.self,
      NewCommand.self,
      ObserveCommand.self,
      PullCommand.self,
      PushCommand.self,
      RemoteCommand.self,
      RmCommand.self,
      SyncCommand.self,
      TargetCommand.self,
      VersionCommand.self,
    ]
  )

  public init() {}
}
