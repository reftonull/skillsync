import Dependencies
import Foundation

public struct CopyDirectoryFeature {
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(
    from source: URL,
    to destination: URL,
    excluding excludedNames: Set<String> = []
  ) throws {
    try copyDirectory(from: source, to: destination, excluding: excludedNames)
  }

  private func copyDirectory(
    from source: URL,
    to destination: URL,
    excluding excludedNames: Set<String>
  ) throws {
    try fileSystemClient.createDirectory(destination, true)
    let children = try fileSystemClient.contentsOfDirectory(source)
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    for child in children {
      if excludedNames.contains(child.lastPathComponent) {
        continue
      }
      let target = destination.appendingPathComponent(
        child.lastPathComponent,
        isDirectory: fileSystemClient.isDirectory(child.path)
      )
      if fileSystemClient.isDirectory(child.path) {
        try copyDirectory(from: child, to: target, excluding: excludedNames)
      } else {
        try fileSystemClient.createDirectory(target.deletingLastPathComponent(), true)
        try fileSystemClient.write(try fileSystemClient.data(child), target)
      }
    }
  }
}
