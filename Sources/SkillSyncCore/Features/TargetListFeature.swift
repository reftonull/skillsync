import Foundation

public struct TargetListFeature {
  public struct Result: Equatable, Sendable {
    public var targets: [SyncTarget]

    public init(targets: [SyncTarget]) {
      self.targets = targets
    }
  }

  public init() {}

  public func run() throws -> Result {
    let config = try LoadSyncConfigFeature().run()
    return Result(targets: config.targets)
  }
}
