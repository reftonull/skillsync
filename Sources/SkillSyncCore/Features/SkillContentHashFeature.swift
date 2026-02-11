#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
import Dependencies
import Foundation

public struct SkillContentHashFeature {
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(skillDirectory: URL) throws -> String {
    var files: [URL] = []
    try collectFiles(in: skillDirectory, into: &files)

    let sortedFiles =
      files
      .filter { $0.lastPathComponent != ".meta.toml" }
      .sorted {
        relativePath($0, base: skillDirectory) < relativePath($1, base: skillDirectory)
      }

    var fileMap: [String: Data] = [:]
    for file in sortedFiles {
      let relative = relativePath(file, base: skillDirectory)
      fileMap[relative] = try fileSystemClient.data(file)
    }

    return Self.hash(files: fileMap)
  }

  public static func hash(files: [String: Data]) -> String {
    let sortedPaths = files.keys
      .filter { $0 != ".meta.toml" }
      .sorted()

    var hasher = SHA256()
    for path in sortedPaths {
      guard let data = files[path] else { continue }
      hasher.update(data: Data(path.utf8))
      hasher.update(data: Data([0]))
      hasher.update(data: data)
      hasher.update(data: Data([0]))
    }

    let digest = hasher.finalize()
    return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
  }

  private func collectFiles(in directory: URL, into files: inout [URL]) throws {
    let children = try fileSystemClient.contentsOfDirectory(directory)
      .sorted { $0.path < $1.path }

    for child in children {
      if fileSystemClient.isDirectory(child.path) {
        try collectFiles(in: child, into: &files)
      } else {
        files.append(child)
      }
    }
  }

  private func relativePath(_ path: URL, base: URL) -> String {
    let basePath = base.standardizedFileURL.path
    let fullPath = path.standardizedFileURL.path
    if fullPath.hasPrefix(basePath + "/") {
      return String(fullPath.dropFirst(basePath.count + 1))
    }
    return path.lastPathComponent
  }
}
