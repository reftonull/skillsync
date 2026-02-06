import Dependencies
import Foundation

public struct OutputClient: Sendable {
  public var stdout: @Sendable (String) -> Void
  public var stderr: @Sendable (String) -> Void

  public init(
    stdout: @escaping @Sendable (String) -> Void,
    stderr: @escaping @Sendable (String) -> Void
  ) {
    self.stdout = stdout
    self.stderr = stderr
  }
}

private enum OutputClientKey: DependencyKey {
  static var liveValue: OutputClient {
    OutputClient(
      stdout: { Swift.print($0) },
      stderr: { message in
        let data = Data((message + "\n").utf8)
        FileHandle.standardError.write(data)
      }
    )
  }

  static var testValue: OutputClient {
    OutputClient(
      stdout: { _ in },
      stderr: { _ in }
    )
  }
}

public extension DependencyValues {
  var outputClient: OutputClient {
    get { self[OutputClientKey.self] }
    set { self[OutputClientKey.self] = newValue }
  }
}
