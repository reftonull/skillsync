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
    var symbolicLinks: [String: String]
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
      symbolicLinks: [:],
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
          state.files[normalized] != nil
            || state.directories.contains(normalized)
            || state.symbolicLinks[normalized] != nil
        }
      },
      isDirectory: { [state] path in
        state.withValue { state in
          state.directories.contains(normalize(path))
        }
      },
      isSymbolicLink: { [state] path in
        state.withValue { state in
          state.symbolicLinks[normalize(path)] != nil
        }
      },
      createDirectory: { url, withIntermediateDirectories in
        try fileSystem.createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
      },
      contentsOfDirectory: { url in
        try fileSystem.contentsOfDirectory(at: url)
      },
      write: { data, url in
        try fileSystem.write(data, to: url)
      },
      data: { url in
        try fileSystem.data(at: url)
      },
      createSymbolicLink: { link, destination in
        try fileSystem.createSymbolicLink(at: link, destination: destination)
      },
      destinationOfSymbolicLink: { link in
        try fileSystem.destinationOfSymbolicLink(at: link)
      },
      removeItem: { url in
        try fileSystem.removeItem(at: url)
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
      guard state.symbolicLinks[path] == nil else {
        throw Error.fileExists(path)
      }

      if createIntermediates {
        for directory in pathPrefixes(path) {
          guard state.files[directory] == nil, state.symbolicLinks[directory] == nil else {
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
      guard state.symbolicLinks[path] == nil else {
        throw Error.fileExists(path)
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
      guard state.symbolicLinks[path] == nil else {
        throw Error.fileNotFound(path)
      }
      guard let data = state.files[path] else {
        throw Error.fileNotFound(path)
      }
      return data
    }
  }

  public func contentsOfDirectory(at url: URL) throws -> [URL] {
    let directory = normalize(url)
    return try state.withValue { state in
      if state.files[directory] != nil {
        throw Error.notDirectory(directory)
      }
      guard state.directories.contains(directory) else {
        throw Error.directoryNotFound(directory)
      }

      var children: Set<String> = []

      let prefix = directory == "/" ? "/" : directory + "/"
      for childDirectory in state.directories where childDirectory.hasPrefix(prefix) {
        let suffix = String(childDirectory.dropFirst(prefix.count))
        guard !suffix.isEmpty else { continue }
        if !suffix.contains("/") {
          children.insert(prefix + suffix)
        } else if let firstComponent = suffix.split(separator: "/").first {
          children.insert(prefix + firstComponent)
        }
      }

      for file in state.files.keys where file.hasPrefix(prefix) {
        let suffix = String(file.dropFirst(prefix.count))
        guard !suffix.isEmpty else { continue }
        if !suffix.contains("/") {
          children.insert(prefix + suffix)
        } else if let firstComponent = suffix.split(separator: "/").first {
          children.insert(prefix + firstComponent)
        }
      }

      for link in state.symbolicLinks.keys where link.hasPrefix(prefix) {
        let suffix = String(link.dropFirst(prefix.count))
        guard !suffix.isEmpty else { continue }
        if !suffix.contains("/") {
          children.insert(prefix + suffix)
        } else if let firstComponent = suffix.split(separator: "/").first {
          children.insert(prefix + firstComponent)
        }
      }

      return
        children
        .sorted()
        .map { URL(filePath: $0) }
    }
  }

  public func createSymbolicLink(at link: URL, destination: URL) throws {
    let path = normalize(link)
    let parent = normalize(link.deletingLastPathComponent())
    let target = normalize(destination)
    try state.withValue { state in
      guard state.directories.contains(parent) else {
        throw Error.directoryNotFound(parent)
      }
      guard state.files[path] == nil, !state.directories.contains(path), state.symbolicLinks[path] == nil else {
        throw Error.fileExists(path)
      }
      state.symbolicLinks[path] = target
    }
  }

  public func destinationOfSymbolicLink(at link: URL) throws -> URL {
    let path = normalize(link)
    return try state.withValue { state in
      guard let target = state.symbolicLinks[path] else {
        throw Error.fileNotFound(path)
      }
      return URL(filePath: target)
    }
  }

  public func removeItem(at url: URL) throws {
    let path = normalize(url)
    try state.withValue { state in
      if state.files.removeValue(forKey: path) != nil {
        return
      }
      if state.symbolicLinks.removeValue(forKey: path) != nil {
        return
      }
      if state.directories.contains(path) {
        let prefix = path == "/" ? "/" : path + "/"
        state.files = state.files.filter { key, _ in
          !(key == path || key.hasPrefix(prefix))
        }
        state.symbolicLinks = state.symbolicLinks.filter { key, _ in
          !(key == path || key.hasPrefix(prefix))
        }
        state.directories = Set(
          state.directories.filter { key in
            !(key == path || key.hasPrefix(prefix))
          })
        return
      }
      throw Error.fileNotFound(path)
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
      for (path, destination) in state.symbolicLinks.sorted(by: { $0.key < $1.key }) {
        lines.append("symlink \(path) -> \(destination)")
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
