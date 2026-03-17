import Dependencies
import Foundation

public struct AgentRegistryClient: Sendable {
  public var entryFor: @Sendable (String) -> AgentRegistryEntry?
  public var allEntries: @Sendable () -> [AgentRegistryEntry]
  public var projectDirectories: @Sendable () -> [String: String]

  public init(
    entryFor: @escaping @Sendable (String) -> AgentRegistryEntry?,
    allEntries: @escaping @Sendable () -> [AgentRegistryEntry],
    projectDirectories: @escaping @Sendable () -> [String: String]
  ) {
    self.entryFor = entryFor
    self.allEntries = allEntries
    self.projectDirectories = projectDirectories
  }
}

private enum AgentRegistryClientKey: DependencyKey {
  static var liveValue: AgentRegistryClient {
    let registry = AgentRegistryEntry.registry
    return AgentRegistryClient(
      entryFor: { id in registry.first { $0.id == id } },
      allEntries: { registry },
      projectDirectories: {
        Dictionary(uniqueKeysWithValues: registry.map { ($0.id, $0.projectDirectory) })
      }
    )
  }

  static var testValue: AgentRegistryClient {
    AgentRegistryClient(
      entryFor: { _ in
        fatalError(
          """
          Unimplemented AgentRegistryClient.entryFor.
          Override `agentRegistryClient` in this test using `.dependencies { ... }`.
          """
        )
      },
      allEntries: {
        fatalError(
          """
          Unimplemented AgentRegistryClient.allEntries.
          Override `agentRegistryClient` in this test using `.dependencies { ... }`.
          """
        )
      },
      projectDirectories: {
        fatalError(
          """
          Unimplemented AgentRegistryClient.projectDirectories.
          Override `agentRegistryClient` in this test using `.dependencies { ... }`.
          """
        )
      }
    )
  }
}

public extension DependencyValues {
  var agentRegistryClient: AgentRegistryClient {
    get { self[AgentRegistryClientKey.self] }
    set { self[AgentRegistryClientKey.self] = newValue }
  }
}
