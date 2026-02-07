import Foundation

public struct SyncTarget: Equatable, Sendable {
  public enum Source: String, Equatable, Sendable {
    case tool
    case path
    case project
  }

  public var id: String
  public var path: String
  public var source: Source

  public init(id: String, path: String, source: Source) {
    self.id = id
    self.path = path
    self.source = source
  }

  public var resolvedPathURL: URL {
    URL(filePath: path, directoryHint: .isDirectory)
  }
}
