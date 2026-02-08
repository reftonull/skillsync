import ArgumentParser

public struct RemoteCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "remote",
    abstract: "Manage git remotes for the skillsync store.",
    subcommands: [
      RemoteSetCommand.self,
    ]
  )

  public init() {}
}
