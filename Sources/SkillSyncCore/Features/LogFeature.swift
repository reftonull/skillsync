import Dependencies
import Foundation

public struct LogFeature {
  public struct Input: Equatable, Sendable {
    public var name: String
    public var summary: Bool

    public init(name: String, summary: Bool) {
      self.name = name
      self.summary = summary
    }
  }

  public struct Result: Equatable, Sendable {
    public var name: String
    public var totalInvocations: Int
    public var positive: Int
    public var negative: Int
    public var lines: [String]

    public init(
      name: String,
      totalInvocations: Int,
      positive: Int,
      negative: Int,
      lines: [String]
    ) {
      self.name = name
      self.totalInvocations = totalInvocations
      self.positive = positive
      self.negative = negative
      self.lines = lines
    }
  }

  public enum Error: Swift.Error, Equatable, CustomStringConvertible {
    case skillNotFound(String)

    public var description: String {
      switch self {
      case let .skillNotFound(name):
        return "Skill '\(name)' not found."
      }
    }
  }

  private struct LogRecord: Decodable {
    var ts: String
    var signal: ObserveFeature.Signal
    var note: String?
    var version: Int?
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let storeRoot = pathClient.skillsyncRoot()
    let skillRoot = storeRoot
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(input.name, isDirectory: true)
    guard fileSystemClient.fileExists(skillRoot.path), fileSystemClient.isDirectory(skillRoot.path) else {
      throw Error.skillNotFound(input.name)
    }

    let logURL = storeRoot
      .appendingPathComponent("logs", isDirectory: true)
      .appendingPathComponent("\(input.name).jsonl")

    let records = try self.loadRecords(logURL: logURL)
    let positive = records.filter { $0.signal == .positive }.count
    let negative = records.filter { $0.signal == .negative }.count
    let total = records.count

    let lines: [String]
    if input.summary {
      lines = [Self.summaryLine(name: input.name, total: total, positive: positive, negative: negative)]
    } else {
      lines = records.map(Self.recordLine(record:))
    }

    return .init(
      name: input.name,
      totalInvocations: total,
      positive: positive,
      negative: negative,
      lines: lines
    )
  }

  private func loadRecords(logURL: URL) throws -> [LogRecord] {
    guard fileSystemClient.fileExists(logURL.path), !fileSystemClient.isDirectory(logURL.path) else {
      return []
    }

    let raw = String(decoding: try fileSystemClient.data(logURL), as: UTF8.self)
    let lines = raw
      .split(separator: "\n", omittingEmptySubsequences: true)
      .map(String.init)

    guard !lines.isEmpty else { return [] }
    let decoder = JSONDecoder()
    return try lines.map { line in
      try decoder.decode(LogRecord.self, from: Data(line.utf8))
    }
  }

  private static func recordLine(record: LogRecord) -> String {
    if let note = record.note {
      return "\(record.ts)  \(record.signal.rawValue)  \"\(note)\""
    }
    return "\(record.ts)  \(record.signal.rawValue)"
  }

  private static func summaryLine(name: String, total: Int, positive: Int, negative: Int) -> String {
    guard total > 0 else { return "\(name): 0 invocations" }
    let percent = Int((Double(negative) / Double(total) * 100).rounded())
    return "\(name): \(total) invocations, \(positive) positive, \(negative) negative (\(percent)% negative)"
  }
}
