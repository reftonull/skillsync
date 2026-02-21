import Testing

@testable import SkillSyncCLI

extension BaseSuite {
  @Suite
  struct OutputFormattingTests {
    // MARK: - alignedRows

    @Test
    func alignedRowsReturnsEmptyForEmptyInput() {
      #expect(OutputFormatting.alignedRows([]) == [])
    }

    @Test
    func alignedRowsReturnsEmptyForAllEmptyRows() {
      #expect(OutputFormatting.alignedRows([[], []]) == [])
    }

    @Test
    func alignedRowsSingleColumnNosPadding() {
      let result = OutputFormatting.alignedRows([["hello"], ["hi"]])
      // Last (and only) column never gets padded
      #expect(result == ["hello", "hi"])
    }

    @Test
    func alignedRowsPadsShortValuesInFirstColumn() {
      let result = OutputFormatting.alignedRows([
        ["ID", "PATH"],
        ["codex", "~/.codex/skills"],
        ["cursor", "~/.cursor/skills"],
      ])
      // "ID" pads to 6 chars (width of "cursor")
      #expect(result[0] == "ID      PATH")
      #expect(result[1] == "codex   ~/.codex/skills")
      #expect(result[2] == "cursor   ~/.cursor/skills")
    }

    @Test
    func alignedRowsHandlesUnevenColumnCounts() {
      // Rows with fewer columns than the max should not crash
      let result = OutputFormatting.alignedRows([
        ["a", "b", "c"],
        ["longer"],
      ])
      #expect(result.count == 2)
    }

    @Test
    func alignedRowsColumnsJoinedByThreeSpaces() {
      let result = OutputFormatting.alignedRows([["x", "y"]])
      #expect(result == ["x   y"])
    }

    // MARK: - json

    @Test
    func jsonProducesPrettyPrintedOutput() throws {
      struct Payload: Encodable {
        let name: String
        let count: Int
      }
      let output = try OutputFormatting.json(Payload(name: "pdf", count: 3))
      #expect(output.contains("\"name\" : \"pdf\""))
      #expect(output.contains("\"count\" : 3"))
      // pretty-printed means newlines present
      #expect(output.contains("\n"))
    }

    @Test
    func jsonSortsKeys() throws {
      struct Payload: Encodable {
        let zebra: String
        let alpha: String
      }
      let output = try OutputFormatting.json(Payload(zebra: "z", alpha: "a"))
      let alphaRange = output.range(of: "\"alpha\"")!
      let zebraRange = output.range(of: "\"zebra\"")!
      #expect(alphaRange.lowerBound < zebraRange.lowerBound)
    }

    @Test
    func jsonHandlesArray() throws {
      let output = try OutputFormatting.json(["one", "two"])
      #expect(output.contains("\"one\""))
      #expect(output.contains("\"two\""))
    }
  }
}
