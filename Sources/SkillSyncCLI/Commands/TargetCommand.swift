import ArgumentParser

public struct TargetCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "target",
    abstract: "Manage sync targets.",
    subcommands: [
      TargetAddCommand.self,
      TargetRemoveCommand.self,
      TargetListCommand.self,
    ]
  )

  public init() {}
}
