import Dependencies
import Foundation

public struct PathClient: Sendable {
  public var homeDirectory: @Sendable () -> URL
  public var currentDirectory: @Sendable () -> URL

  public init(
    homeDirectory: @escaping @Sendable () -> URL,
    currentDirectory: @escaping @Sendable () -> URL
  ) {
    self.homeDirectory = homeDirectory
    self.currentDirectory = currentDirectory
  }

  public var skillsyncRoot: @Sendable () -> URL {
    let homeDirectory = self.homeDirectory
    return {
      homeDirectory().appendingPathComponent(".skillsync", isDirectory: true)
    }
  }

  public var resolvePath: @Sendable (String) -> URL {
    let homeDirectory = self.homeDirectory
    let currentDirectory = self.currentDirectory
    return { rawPath in
      let expandedPath: String
      if rawPath == "~" {
        expandedPath = homeDirectory().path
      } else if rawPath.hasPrefix("~/") {
        expandedPath = homeDirectory().path + "/" + rawPath.dropFirst(2)
      } else {
        expandedPath = rawPath
      }

      if expandedPath.hasPrefix("/") {
        return URL(filePath: expandedPath, directoryHint: .isDirectory).standardizedFileURL
      } else {
        return currentDirectory()
          .appendingPathComponent(expandedPath, isDirectory: true)
          .standardizedFileURL
      }
    }
  }
}

private enum PathClientKey: DependencyKey {
  static var liveValue: PathClient {
    PathClient(
      homeDirectory: { FileManager.default.homeDirectoryForCurrentUser },
      currentDirectory: {
        URL(filePath: FileManager.default.currentDirectoryPath, directoryHint: .isDirectory)
      }
    )
  }

  static var testValue: PathClient {
    PathClient(
      homeDirectory: { URL(filePath: "/Users/blob", directoryHint: .isDirectory) },
      currentDirectory: { URL(filePath: "/Users/blob/project", directoryHint: .isDirectory) }
    )
  }
}

public extension DependencyValues {
  var pathClient: PathClient {
    get { self[PathClientKey.self] }
    set { self[PathClientKey.self] = newValue }
  }
}
