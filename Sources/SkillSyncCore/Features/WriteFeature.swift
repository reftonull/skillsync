import Dependencies
import Foundation

public struct WriteFeature {
  public struct Input: Equatable, Sendable {
    public var skillName: String
    public var destinationRelativePath: String
    public var sourcePath: String

    public init(skillName: String, destinationRelativePath: String, sourcePath: String) {
      self.skillName = skillName
      self.destinationRelativePath = destinationRelativePath
      self.sourcePath = sourcePath
    }
  }

  public struct Result: Equatable, Sendable {
    public var destinationPath: String
    public var contentHash: String

    public init(destinationPath: String, contentHash: String) {
      self.destinationPath = destinationPath
      self.contentHash = contentHash
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case invalidDestinationPath(String)
    case reservedPath(String)
    case skillNotFound(String)

    public var description: String {
      switch self {
      case let .invalidDestinationPath(path):
        return "Invalid destination path '\(path)'."
      case let .reservedPath(path):
        return "Destination path '\(path)' is reserved."
      case let .skillNotFound(name):
        return "Skill '\(name)' not found."
      }
    }
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    try Self.validate(destinationRelativePath: input.destinationRelativePath)

    let skillRoot = pathClient.skillsyncRoot()
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(input.skillName, isDirectory: true)
    guard fileSystemClient.fileExists(skillRoot.path) else {
      throw Error.skillNotFound(input.skillName)
    }

    let sourceURL = pathClient.resolvePath(input.sourcePath)
    let sourceData = try fileSystemClient.data(sourceURL)

    let destinationURL = skillRoot.appendingPathComponent(input.destinationRelativePath)
    let destinationParent = destinationURL.deletingLastPathComponent()
    try fileSystemClient.createDirectory(destinationParent, true)
    try fileSystemClient.write(sourceData, destinationURL)

    let contentHash = try SkillContentHashFeature().run(skillDirectory: skillRoot)
    try updateMetaContentHash(skillRoot: skillRoot, contentHash: contentHash)

    return Result(
      destinationPath: input.destinationRelativePath,
      contentHash: contentHash
    )
  }

  private func updateMetaContentHash(skillRoot: URL, contentHash: String) throws {
    let metaURL = skillRoot.appendingPathComponent(".meta.toml")
    let metaData = try fileSystemClient.data(metaURL)
    var meta = String(decoding: metaData, as: UTF8.self)
    let lines = meta.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
    if let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("content-hash = ") }) {
      var mutable = lines.map(String.init)
      mutable[index] = "content-hash = \"\(contentHash)\""
      meta = mutable.joined(separator: "\n")
    } else {
      if !meta.hasSuffix("\n") { meta += "\n" }
      meta += "content-hash = \"\(contentHash)\"\n"
    }
    try fileSystemClient.write(Data(meta.utf8), metaURL)
  }

  static func validate(destinationRelativePath path: String) throws {
    let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw Error.invalidDestinationPath(path)
    }

    if (trimmed as NSString).isAbsolutePath {
      throw Error.invalidDestinationPath(path)
    }

    let components = trimmed.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    if components.contains("..") {
      throw Error.invalidDestinationPath(path)
    }

    if components.first == ".meta.toml" {
      throw Error.reservedPath(path)
    }
  }
}
