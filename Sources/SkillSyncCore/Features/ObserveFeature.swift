import Dependencies
import Foundation

public struct ObserveFeature {
  public enum Signal: String, Equatable, Sendable, Codable {
    case positive
    case negative
  }

  public struct Input: Equatable, Sendable {
    public var name: String
    public var signal: Signal
    public var note: String?

    public init(name: String, signal: Signal, note: String?) {
      self.name = name
      self.signal = signal
      self.note = note
    }
  }

  public struct Result: Equatable, Sendable {
    public var name: String
    public var signal: Signal
    public var ts: String
    public var version: Int
    public var logPath: URL

    public init(
      name: String,
      signal: Signal,
      ts: String,
      version: Int,
      logPath: URL
    ) {
      self.name = name
      self.signal = signal
      self.ts = ts
      self.version = version
      self.logPath = logPath
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

  private struct LogRecord: Encodable {
    var ts: String
    var signal: Signal
    var version: Int
    var note: String?
  }

  @Dependency(\.pathClient) var pathClient
  @Dependency(\.fileSystemClient) var fileSystemClient
  @Dependency(\.date.now) var now

  public init() {}

  public func run(_ input: Input) throws -> Result {
    let storeRoot = pathClient.skillsyncRoot()
    let skillRoot = storeRoot
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent(input.name, isDirectory: true)
    guard fileSystemClient.fileExists(skillRoot.path), fileSystemClient.isDirectory(skillRoot.path) else {
      throw Error.skillNotFound(input.name)
    }

    let metaURL = skillRoot.appendingPathComponent(".meta.toml")
    let meta = try UpdateMetaFeature().read(metaURL: metaURL)
    let version = meta.int(section: "skill", key: "version") ?? 0
    let timestamp = Self.formatDate(now)

    let logsRoot = storeRoot.appendingPathComponent("logs", isDirectory: true)
    try fileSystemClient.createDirectory(logsRoot, true)
    let logURL = logsRoot.appendingPathComponent("\(input.name).jsonl")

    let record = LogRecord(
      ts: timestamp,
      signal: input.signal,
      version: version,
      note: input.note
    )
    try append(record: record, to: logURL)

    var updates: [UpdateMetaFeature.FieldUpdate] = [
      .init(section: "stats", key: "total-invocations", operation: .incrementInt(1))
    ]
    switch input.signal {
    case .positive:
      updates.append(.init(section: "stats", key: "positive", operation: .incrementInt(1)))
    case .negative:
      updates.append(.init(section: "stats", key: "negative", operation: .incrementInt(1)))
    }

    try UpdateMetaFeature().run(
      metaURL: metaURL,
      updates: updates
    )

    return .init(
      name: input.name,
      signal: input.signal,
      ts: timestamp,
      version: version,
      logPath: logURL
    )
  }

  private func append(record: LogRecord, to logURL: URL) throws {
    let encoder = JSONEncoder()
    let line = String(decoding: try encoder.encode(record), as: UTF8.self)

    let existing: String
    if fileSystemClient.fileExists(logURL.path) {
      existing = String(decoding: try fileSystemClient.data(logURL), as: UTF8.self)
    } else {
      existing = ""
    }

    let updated: String
    if existing.isEmpty {
      updated = line + "\n"
    } else if existing.hasSuffix("\n") {
      updated = existing + line + "\n"
    } else {
      updated = existing + "\n" + line + "\n"
    }

    try fileSystemClient.write(Data(updated.utf8), logURL)
  }

  private static func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
  }
}
