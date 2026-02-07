import Dependencies
import Foundation

public struct BuiltInSkillsClient: Sendable {
  public var load: @Sendable () throws -> [BuiltInSkill]

  public init(load: @escaping @Sendable () throws -> [BuiltInSkill]) {
    self.load = load
  }
}

private enum BuiltInSkillsClientKey: DependencyKey {
  static var liveValue: BuiltInSkillsClient {
    BuiltInSkillsClient(
      load: { try BuiltInSkill.seeded() }
    )
  }

  static var testValue: BuiltInSkillsClient {
    BuiltInSkillsClient(
      load: {
        fatalError(
          """
          Unimplemented BuiltInSkillsClient.load.
          Override `builtInSkillsClient` in this test using `.dependencies { ... }`.
          """
        )
      }
    )
  }
}

public extension DependencyValues {
  var builtInSkillsClient: BuiltInSkillsClient {
    get { self[BuiltInSkillsClientKey.self] }
    set { self[BuiltInSkillsClientKey.self] = newValue }
  }
}
