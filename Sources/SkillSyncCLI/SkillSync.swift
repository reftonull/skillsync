import ArgumentParser

public struct SkillSync: AsyncParsableCommand {
  public static let version = "0.1.0"

  public static let configuration = CommandConfiguration(
    commandName: "skillsync",
    abstract: "Manage AI-agent skills from one canonical local store.",
    version: version,
    subcommands: [
      AddCommand.self,
      InitCommand.self,
      NewCommand.self,
      SyncCommand.self,
      VersionCommand.self,
      WriteCommand.self,
    ]
  )

  public init() {}
}
