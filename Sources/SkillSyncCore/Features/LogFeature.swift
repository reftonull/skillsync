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

  public struct Result: Equatable, Sendable, Encodable {
    public struct ObservationRecord: Equatable, Sendable, Encodable {
      public var timestamp: String
      public var signal: ObserveFeature.Signal
      public var note: String?
      public var version: Int?

      public init(
        timestamp: String,
        signal: ObserveFeature.Signal,
        note: String?,
        version: Int?
      ) {
        self.timestamp = timestamp
        self.signal = signal
        self.note = note
        self.version = version
      }
    }

    public var name: String
    public var totalInvocations: Int
    public var positive: Int
    public var negative: Int
    public var records: [ObservationRecord]
    public var lines: [String]

    public init(
      name: String,
      totalInvocations: Int,
      positive: Int,
      negative: Int,
      records: [ObservationRecord],
      lines: [String]
    ) {
      self.name = name
      self.totalInvocations = totalInvocations
      self.positive = positive
      self.negative = negative
      self.records = records
      self.lines = lines
    }

    enum CodingKeys: String, CodingKey {
      case name
      case totalInvocations
      case positive
      case negative
      case records
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

  private struct StoredLogRecord: Decodable {
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

    let storedRecords = try self.loadRecords(logURL: logURL)
    let positive = storedRecords.filter { $0.signal == .positive }.count
    let negative = storedRecords.filter { $0.signal == .negative }.count
    let total = storedRecords.count
    let records = storedRecords.map {
      Result.ObservationRecord(
        timestamp: $0.ts,
        signal: $0.signal,
        note: $0.note,
        version: $0.version
      )
    }

    let lines: [String] =
      input.summary
      ? [Self.summaryLine(name: input.name, total: total, positive: positive, negative: negative)]
      : []

    return .init(
      name: input.name,
      totalInvocations: total,
      positive: positive,
      negative: negative,
      records: records,
      lines: lines
    )
  }

  private func loadRecords(logURL: URL) throws -> [StoredLogRecord] {
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
      try decoder.decode(StoredLogRecord.self, from: Data(line.utf8))
    }
  }

  private static func summaryLine(name: String, total: Int, positive: Int, negative: Int) -> String {
    guard total > 0 else { return "\(name): 0 invocations" }
    let percent = Int((Double(negative) / Double(total) * 100).rounded())
    return "\(name): \(total) invocations, \(positive) positive, \(negative) negative (\(percent)% negative)"
  }
}
