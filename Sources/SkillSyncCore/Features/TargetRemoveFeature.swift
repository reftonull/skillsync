import Foundation

public struct TargetRemoveFeature {
  public struct Input: Equatable, Sendable {
    public var id: String

    public init(id: String) {
      self.id = id
    }
  }

  public struct Result: Equatable, Sendable {
    public var removed: SyncTarget

    public init(removed: SyncTarget) {
      self.removed = removed
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case targetNotFound(String)

    public var description: String {
      switch self {
      case let .targetNotFound(id):
        return "Target '\(id)' not found."
      }
    }
  }

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let config = try LoadSyncConfigFeature().run()
    guard let index = config.targets.firstIndex(where: { $0.id == input.id }) else {
      throw Error.targetNotFound(input.id)
    }

    var targets = config.targets
    let removed = targets.remove(at: index)
    try SaveSyncConfigFeature().run(
      .init(
        targets: targets,
        observation: config.observation
      )
    )
    return Result(removed: removed)
  }
}
