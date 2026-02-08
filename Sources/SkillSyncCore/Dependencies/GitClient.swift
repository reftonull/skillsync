import Dependencies
import Foundation

public struct GitClient: Sendable {
  public struct CommandResult: Equatable, Sendable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
      self.exitCode = exitCode
      self.stdout = stdout
      self.stderr = stderr
    }

    public var succeeded: Bool {
      exitCode == 0
    }
  }

  public var run: @Sendable (_ workingDirectory: URL, _ arguments: [String]) throws -> CommandResult

  public init(
    run: @escaping @Sendable (_ workingDirectory: URL, _ arguments: [String]) throws -> CommandResult
  ) {
    self.run = run
  }

  public static let live = GitClient(
    run: { workingDirectory, arguments in
      let process = Process()
      process.executableURL = URL(filePath: "/usr/bin/env")
      process.arguments = ["git"] + arguments
      process.currentDirectoryURL = workingDirectory

      let stdoutPipe = Pipe()
      let stderrPipe = Pipe()
      process.standardOutput = stdoutPipe
      process.standardError = stderrPipe

      try process.run()
      process.waitUntilExit()

      let stdout = String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
      let stderr = String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

      return CommandResult(
        exitCode: process.terminationStatus,
        stdout: stdout,
        stderr: stderr
      )
    }
  )
}

public extension GitClient {
  @discardableResult
  func runRequired<E: Swift.Error>(
    _ workingDirectory: URL,
    _ arguments: [String],
    error: (String, String) -> E
  ) throws -> CommandResult {
    let result = try self.run(workingDirectory, arguments)
    guard result.succeeded else {
      throw error(
        Self.commandString(arguments),
        Self.commandDetails(stdout: result.stdout, stderr: result.stderr)
      )
    }
    return result
  }

  static func commandString(_ arguments: [String]) -> String {
    (["git"] + arguments).joined(separator: " ")
  }

  static func commandDetails(stdout: String, stderr: String) -> String {
    [stderr, stdout]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: "\n")
  }
}

private enum GitClientKey: DependencyKey {
  static var liveValue: GitClient {
    .live
  }

  static var testValue: GitClient {
    GitClient(
      run: { _, _ in
        testDependencyFailure("run")
      }
    )
  }
}

private func testDependencyFailure<T>(_ endpoint: StaticString) -> T {
  fatalError(
    """
    Unimplemented GitClient.\(endpoint).
    Override `gitClient` in this test using `.dependencies { ... }`.
    """
  )
}

public extension DependencyValues {
  var gitClient: GitClient {
    get { self[GitClientKey.self] }
    set { self[GitClientKey.self] = newValue }
  }
}
