import ConcurrencyExtras
import Foundation
import SkillSyncCore

public final class InMemoryFileSystem: Sendable {
  public enum Error: Swift.Error, Equatable {
    case directoryNotFound(String)
    case fileNotFound(String)
    case fileExists(String)
    case notDirectory(String)
    case isDirectory(String)
  }

  struct State {
    var files: [String: Data]
    var directories: Set<String>
    var homeDirectoryForCurrentUser: URL
  }

  let state: LockIsolated<State>

  public init(
    homeDirectoryForCurrentUser: URL = URL(filePath: "/Users/blob", directoryHint: .isDirectory),
    files: [String: Data] = [:],
    directories: Set<String> = []
  ) {
    let state = State(
      files: files,
      directories: directories,
      homeDirectoryForCurrentUser: homeDirectoryForCurrentUser
    )
    self.state = LockIsolated(state)
    self.state.withValue {
      _ = $0.directories.insert(normalize(homeDirectoryForCurrentUser))
      _ = $0.directories.insert(normalize(URL(filePath: "/tmp", directoryHint: .isDirectory)))
    }
  }

  public var homeDirectoryForCurrentUser: URL {
    state.withValue(\.homeDirectoryForCurrentUser)
  }

  public var client: FileSystemClient {
    let fileSystem = self
    return FileSystemClient(
      fileExists: { [state] path in
        let normalized = normalize(path)
        return state.withValue { state in
          state.files[normalized] != nil || state.directories.contains(normalized)
        }
      },
      createDirectory: { url, withIntermediateDirectories in
        try fileSystem.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
      },
      write: { data, url in
        try fileSystem.write(data, to: url)
      },
      data: { url in
        try fileSystem.data(at: url)
      }
    )
  }

  public func setFile(_ data: Data = Data(), atPath path: String) {
    state.withValue { $0.files[normalize(path)] = data }
  }

  public func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool)
    throws
  {
    let path = normalize(url)
    try state.withValue { state in
      guard state.files[path] == nil else {
        throw Error.fileExists(path)
      }

      if createIntermediates {
        for directory in pathPrefixes(path) {
          guard state.files[directory] == nil else {
            throw Error.notDirectory(directory)
          }
          _ = state.directories.insert(directory)
        }
      } else {
        let parent = normalize(url.deletingLastPathComponent())
        guard state.directories.contains(parent) else {
          throw Error.directoryNotFound(parent)
        }
        _ = state.directories.insert(path)
      }
    }
  }

  public func write(_ data: Data, to url: URL) throws {
    let path = normalize(url)
    let directory = normalize(url.deletingLastPathComponent())
    try state.withValue { state in
      guard state.directories.contains(directory) else {
        throw Error.directoryNotFound(directory)
      }
      guard !state.directories.contains(path) else {
        throw Error.isDirectory(path)
      }
      state.files[path] = data
    }
  }

  public func data(at url: URL) throws -> Data {
    let path = normalize(url)
    return try state.withValue { state in
      guard !state.directories.contains(path) else {
        throw Error.isDirectory(path)
      }
      guard let data = state.files[path] else {
        throw Error.fileNotFound(path)
      }
      return data
    }
  }
}

extension InMemoryFileSystem: CustomStringConvertible {
  public var description: String {
    state.withValue { state in
      var lines: [String] = []
      for directory in state.directories.sorted() {
        lines.append("dir \(directory)")
      }
      for path in state.files.keys.sorted() {
        let data = state.files[path]!
        let value = data.count < 50 ? "\"\(String(decoding: data, as: UTF8.self))\"" : "(\(data.count) bytes)"
        lines.append("file \(path) \(value)")
      }
      return lines.joined(separator: "\n")
    }
  }
}

private func normalize(_ url: URL) -> String {
  normalize(url.path)
}

private func normalize(_ path: String) -> String {
  let standardized = (path as NSString).standardizingPath
  if standardized == "/" {
    return standardized
  }
  return standardized.hasSuffix("/") ? String(standardized.dropLast()) : standardized
}

private func pathPrefixes(_ path: String) -> [String] {
  let components = (path as NSString).pathComponents
  guard !components.isEmpty else { return [] }
  var current = ""
  var prefixes: [String] = []
  for component in components {
    if component == "/" {
      current = "/"
    } else if current == "/" {
      current += component
    } else if current.isEmpty {
      current = component
    } else {
      current += "/" + component
    }
    prefixes.append(current)
  }
  return prefixes
}
