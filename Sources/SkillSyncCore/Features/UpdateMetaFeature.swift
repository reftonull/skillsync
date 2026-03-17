import Dependencies
import Foundation
import TOMLDecoder

public struct UpdateMetaFeature {
  public struct MetaDocument: Equatable, Sendable {
    public var skill: SkillSection
    public var upstream: UpstreamSection

    public init(
      skill: SkillSection = .init(),
      upstream: UpstreamSection = .init()
    ) {
      self.skill = skill
      self.upstream = upstream
    }

    public struct SkillSection: Equatable, Sendable, Decodable {
      public var created: String?
      public var source: String?
      public var version: Int?
      public var contentHash: String?
      public var state: String?

      public init(
        created: String? = nil,
        source: String? = nil,
        version: Int? = nil,
        contentHash: String? = nil,
        state: String? = nil
      ) {
        self.created = created
        self.source = source
        self.version = version
        self.contentHash = contentHash
        self.state = state
      }

      private enum CodingKeys: String, CodingKey {
        case created
        case source
        case version
        case contentHash = "content-hash"
        case state
      }
    }

    public struct UpstreamSection: Equatable, Sendable, Decodable {
      public var repo: String?
      public var skillPath: String?
      public var ref: String?
      public var commit: String?
      public var baseContentHash: String?

      public init(
        repo: String? = nil,
        skillPath: String? = nil,
        ref: String? = nil,
        commit: String? = nil,
        baseContentHash: String? = nil
      ) {
        self.repo = repo
        self.skillPath = skillPath
        self.ref = ref
        self.commit = commit
        self.baseContentHash = baseContentHash
      }

      private enum CodingKeys: String, CodingKey {
        case repo
        case skillPath = "skill-path"
        case ref
        case commit
        case baseContentHash = "base-content-hash"
      }
    }
  }

  // MARK: - Decodable wrapper for TOMLDecoder

  private struct MetaFile: Decodable {
    var skill: MetaDocument.SkillSection?
    var upstream: MetaDocument.UpstreamSection?
  }

  public struct FieldUpdate: Equatable, Sendable {
    public enum Operation: Equatable, Sendable {
      case setString(String)
      case setInt(Int)
      case setBool(Bool)
      case incrementInt(Int)
    }

    public var section: String
    public var key: String
    public var operation: Operation

    public init(section: String, key: String, operation: Operation) {
      self.section = section
      self.key = key
      self.operation = operation
    }
  }

  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func read(metaURL: URL) throws -> MetaDocument {
    guard fileSystemClient.fileExists(metaURL.path), !fileSystemClient.isDirectory(metaURL.path) else {
      return MetaDocument()
    }
    guard let content = String(data: try fileSystemClient.data(metaURL), encoding: .utf8) else {
      return MetaDocument()
    }
    guard let decoded = try? TOMLDecoder().decode(MetaFile.self, from: content) else {
      return MetaDocument()
    }
    return MetaDocument(
      skill: decoded.skill ?? .init(),
      upstream: decoded.upstream ?? .init()
    )
  }

  public func run(metaURL: URL, updates: [FieldUpdate]) throws {
    var lines = String(
      decoding: try fileSystemClient.data(metaURL),
      as: UTF8.self
    ).split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
      .map(String.init)

    for update in updates {
      apply(update: update, to: &lines)
    }

    let updated = lines.joined(separator: "\n")
    try fileSystemClient.write(Data(updated.utf8), metaURL)
  }

  private func apply(update: FieldUpdate, to lines: inout [String]) {
    let sectionHeader = "[\(update.section)]"

    if let sectionIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == sectionHeader }) {
      let nextSectionIndex =
        lines[(sectionIndex + 1)...]
        .firstIndex(where: {
          $0.trimmingCharacters(in: .whitespaces).hasPrefix("[")
            && $0.trimmingCharacters(in: .whitespaces).hasSuffix("]")
        })
        ?? lines.endIndex

      if let keyLineIndex = lines[(sectionIndex + 1)..<nextSectionIndex]
        .firstIndex(where: {
          $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(update.key) =")
        })
      {
        lines[keyLineIndex] = renderLine(update: update, existingLine: lines[keyLineIndex])
      } else {
        lines.insert(renderLine(update: update, existingLine: nil), at: nextSectionIndex)
      }
      return
    }

    if !lines.isEmpty, let last = lines.last, !last.isEmpty {
      lines.append("")
    }
    lines.append(sectionHeader)
    lines.append(renderLine(update: update, existingLine: nil))
  }

  private func renderLine(update: FieldUpdate, existingLine: String?) -> String {
    let renderedValue: String
    switch update.operation {
    case let .setString(value):
      let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
      renderedValue = "\"\(escaped)\""
    case let .setInt(value):
      renderedValue = "\(value)"
    case let .setBool(value):
      renderedValue = value ? "true" : "false"
    case let .incrementInt(delta):
      let current = existingLine.flatMap(parseIntegerValue) ?? 0
      renderedValue = "\(current + delta)"
    }
    return "\(update.key) = \(renderedValue)"
  }

  private func parseIntegerValue(from line: String) -> Int? {
    guard let equals = line.firstIndex(of: "=") else { return nil }
    let raw = line[line.index(after: equals)...]
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return Int(raw)
  }
}
