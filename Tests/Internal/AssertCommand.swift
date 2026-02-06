import ArgumentParser
import Dependencies
import Foundation
import InlineSnapshotTesting
import Testing

@testable import SkillSyncCLI
import SkillSyncCore

#if canImport(Darwin)
  import Darwin
#else
  @preconcurrency import Glibc
#endif

func assertCommand(
  _ arguments: [String],
  stdout expected: (() -> String)? = nil,
  dependencies updateDependencies: @escaping (inout DependencyValues) throws -> Void = { _ in },
  fileID: StaticString = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  column: UInt = #column
) async throws {
  let output = try await withCapturedStdout {
    try await withDependencies {
      try updateDependencies(&$0)
      $0.outputClient = OutputClient(
        stdout: { Swift.print($0) },
        stderr: { Swift.print($0) }
      )
    } operation: {
      var command = try SkillSync.parseAsRoot(arguments)
      if var command = command as? AsyncParsableCommand {
        try await command.run()
      } else {
        try command.run()
      }
    }
  }

  assertInlineSnapshot(
    of: output,
    as: .lines,
    matches: expected,
    fileID: fileID,
    file: file,
    line: line,
    column: column
  )
}

func assertCommandThrows(
  _ arguments: [String],
  error expected: (() -> String)? = nil,
  dependencies updateDependencies: @escaping (inout DependencyValues) throws -> Void = { _ in },
  fileID: StaticString = #fileID,
  file: StaticString = #filePath,
  line: UInt = #line,
  column: UInt = #column
) async {
  var thrownError: Error?
  do {
    try await withDependencies {
      try updateDependencies(&$0)
    } operation: {
      var command = try SkillSync.parseAsRoot(arguments)
      if var command = command as? AsyncParsableCommand {
        try await command.run()
      } else {
        try command.run()
      }
    }
  } catch {
    thrownError = error
  }

  guard let thrownError else {
    Issue.record(
      "Expected command to throw.",
      sourceLocation: SourceLocation(
        fileID: String(describing: fileID),
        filePath: String(describing: file),
        line: Int(line),
        column: Int(column)
      )
    )
    return
  }

  assertInlineSnapshot(
    of: "\(thrownError)",
    as: .lines,
    matches: expected,
    fileID: fileID,
    file: file,
    line: line,
    column: column
  )
}

private func withCapturedStdout(
  _ body: () async throws -> Void
) async rethrows -> String {
  let pipe = Pipe()
  let original = dup(STDOUT_FILENO)
  fflush(nil)
  dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

  try await body()

  fflush(nil)
  dup2(original, STDOUT_FILENO)
  close(original)
  pipe.fileHandleForWriting.closeFile()
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}
