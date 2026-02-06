import Dependencies
import Foundation

public struct UpdateMetaFeature {
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
      let nextSectionIndex = lines[(sectionIndex + 1)...]
        .firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") && $0.trimmingCharacters(in: .whitespaces).hasSuffix("]") })
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
