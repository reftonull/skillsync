import Foundation

enum OutputFormatting {
  static func json<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }

  static func alignedRows(_ rows: [[String]]) -> [String] {
    guard !rows.isEmpty else { return [] }
    let columnCount = rows.map(\.count).max() ?? 0
    guard columnCount > 0 else { return [] }

    var widths = Array(repeating: 0, count: columnCount)
    for row in rows {
      for index in row.indices {
        widths[index] = max(widths[index], row[index].count)
      }
    }

    return rows.map { row in
      row.enumerated().map { index, value in
        guard index < row.count - 1 else { return value }
        let paddingCount = max(0, widths[index] - value.count)
        return value + String(repeating: " ", count: paddingCount)
      }
      .joined(separator: "   ")
    }
  }
}
