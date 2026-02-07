import CustomDump
import Dependencies
import Foundation

public struct DiffFeature {
  public struct Input: Equatable, Sendable {
    public var name: String

    public init(name: String) {
      self.name = name
    }
  }

  public struct Result: Equatable, Sendable, Codable {
    public struct Summary: Equatable, Sendable, Codable {
      public var added: Int
      public var modified: Int
      public var deleted: Int

      public init(added: Int, modified: Int, deleted: Int) {
        self.added = added
        self.modified = modified
        self.deleted = deleted
      }
    }

    public struct Change: Equatable, Sendable, Codable {
      public enum Status: String, Equatable, Sendable, Codable {
        case added
        case modified
        case deleted
      }

      public enum Kind: String, Equatable, Sendable, Codable {
        case text
        case binary
      }

      public var path: String
      public var status: Status
      public var kind: Kind
      public var patch: String?

      public init(
        path: String,
        status: Status,
        kind: Kind,
        patch: String? = nil
      ) {
        self.path = path
        self.status = status
        self.kind = kind
        self.patch = patch
      }
    }

    public var skill: String
    public var changes: [Change]
    public var summary: Summary

    public init(skill: String, changes: [Change], summary: Summary) {
      self.skill = skill
      self.changes = changes
      self.summary = summary
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case skillNotFound(String)
    case editCopyNotFound(String)

    public var description: String {
      switch self {
      case let .skillNotFound(name):
        return "Skill '\(name)' not found."
      case let .editCopyNotFound(name):
        return "No active edit copy for skill '\(name)'. Run `skillsync edit \(name)` first."
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let storeRoot = pathClient.skillsyncRoot()
    let canonicalRoot = storeRoot
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(input.name, isDirectory: true)
    let editRoot = storeRoot
      .appendingPathComponent("editing", isDirectory: true)
      .appendingPathComponent(input.name, isDirectory: true)

    guard fileSystemClient.fileExists(canonicalRoot.path), fileSystemClient.isDirectory(canonicalRoot.path) else {
      throw Error.skillNotFound(input.name)
    }
    guard fileSystemClient.fileExists(editRoot.path), fileSystemClient.isDirectory(editRoot.path) else {
      throw Error.editCopyNotFound(input.name)
    }

    let canonicalFiles = try fileMap(root: canonicalRoot)
    let editFiles = try fileMap(root: editRoot)

    let allPaths = Set(canonicalFiles.keys).union(editFiles.keys).sorted()
    var changes: [Result.Change] = []
    var added = 0
    var modified = 0
    var deleted = 0

    for path in allPaths {
      let oldData = canonicalFiles[path]
      let newData = editFiles[path]
      switch (oldData, newData) {
      case let (nil, newData?):
        let change = renderChange(path: path, status: .added, oldData: nil, newData: newData)
        changes.append(change)
        added += 1
      case let (oldData?, nil):
        let change = renderChange(path: path, status: .deleted, oldData: oldData, newData: nil)
        changes.append(change)
        deleted += 1
      case let (oldData?, newData?):
        guard oldData != newData else { continue }
        let change = renderChange(path: path, status: .modified, oldData: oldData, newData: newData)
        changes.append(change)
        modified += 1
      case (nil, nil):
        continue
      }
    }

    return Result(
      skill: input.name,
      changes: changes,
      summary: .init(added: added, modified: modified, deleted: deleted)
    )
  }

  private func renderChange(
    path: String,
    status: Result.Change.Status,
    oldData: Data?,
    newData: Data?
  ) -> Result.Change {
    let oldText = oldData.flatMap { String(data: $0, encoding: .utf8) }
    let newText = newData.flatMap { String(data: $0, encoding: .utf8) }
    let isText = (oldData == nil || oldText != nil) && (newData == nil || newText != nil)

    if isText {
      let patch: String?
      switch status {
      case .added:
        patch = newText
      case .deleted:
        patch = oldText
      case .modified:
        if let oldText, let newText {
          patch = diff(oldText, newText)
        } else {
          patch = nil
        }
      }

      return .init(
        path: path,
        status: status,
        kind: .text,
        patch: patch
      )
    }

    let patch: String = switch status {
    case .added:
      "binary file added (\(newData?.count ?? 0) bytes)"
    case .deleted:
      "binary file deleted (\(oldData?.count ?? 0) bytes)"
    case .modified:
      "binary file changed (old: \(oldData?.count ?? 0) bytes, new: \(newData?.count ?? 0) bytes)"
    }

    return .init(
      path: path,
      status: status,
      kind: .binary,
      patch: patch
    )
  }

  private func fileMap(root: URL) throws -> [String: Data] {
    var map: [String: Data] = [:]
    try collectFiles(at: root, relativeRoot: "", into: &map)
    return map
  }

  private func collectFiles(
    at directory: URL,
    relativeRoot: String,
    into map: inout [String: Data]
  ) throws {
    let children = try fileSystemClient.contentsOfDirectory(directory)
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    for child in children {
      let relativePath: String
      if relativeRoot.isEmpty {
        relativePath = child.lastPathComponent
      } else {
        relativePath = "\(relativeRoot)/\(child.lastPathComponent)"
      }

      if relativePath == ".meta.toml" {
        continue
      }

      if fileSystemClient.isDirectory(child.path) {
        try collectFiles(at: child, relativeRoot: relativePath, into: &map)
      } else {
        map[relativePath] = try fileSystemClient.data(child)
      }
    }
  }
}
