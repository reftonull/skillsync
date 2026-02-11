import Dependencies
import Foundation

public struct UpdateMetaFeature {
  public struct MetaDocument: Equatable, Sendable {
    var fields: [String: [String: String]]

    public init(fields: [String: [String: String]] = [:]) {
      self.fields = fields
    }

    public func rawValue(section: String, key: String) -> String? {
      fields[section]?[key]
    }

    public func string(section: String, key: String) -> String? {
      guard let raw = rawValue(section: section, key: key) else { return nil }
      guard raw.count >= 2 else { return nil }
      if raw.hasPrefix("\""), raw.hasSuffix("\"") {
        return String(raw.dropFirst().dropLast())
      }
      if raw.hasPrefix("'"), raw.hasSuffix("'") {
        return String(raw.dropFirst().dropLast())
      }
      return nil
    }

    public func int(section: String, key: String) -> Int? {
      rawValue(section: section, key: key).flatMap(Int.init)
    }

    public func bool(section: String, key: String) -> Bool? {
      switch rawValue(section: section, key: key) {
      case "true": return true
      case "false": return false
      default: return nil
      }
    }
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
    return Self.parse(content: content)
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

  private static func parse(content: String) -> MetaDocument {
    var fields: [String: [String: String]] = [:]
    var currentSection = ""

    for rawLine in content.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
      let line = stripComments(String(rawLine)).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !line.isEmpty else { continue }

      if line.hasPrefix("[") && line.hasSuffix("]") {
        currentSection = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        continue
      }

      guard !currentSection.isEmpty else { continue }
      guard let equals = line.firstIndex(of: "=") else { continue }
      let key = String(line[..<equals]).trimmingCharacters(in: .whitespacesAndNewlines)
      let value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !key.isEmpty else { continue }

      var section = fields[currentSection, default: [:]]
      section[key] = value
      fields[currentSection] = section
    }

    return MetaDocument(fields: fields)
  }

  private static func stripComments(_ line: String) -> String {
    var inString = false
    var delimiter: Character?
    var output = ""

    for character in line {
      if inString {
        output.append(character)
        if character == delimiter {
          inString = false
          delimiter = nil
        }
      } else if character == "\"" || character == "'" {
        inString = true
        delimiter = character
        output.append(character)
      } else if character == "#" {
        break
      } else {
        output.append(character)
      }
    }

    return output
  }
}
