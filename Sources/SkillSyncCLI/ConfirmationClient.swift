import Dependencies
import Foundation

#if canImport(Darwin)
  import Darwin
#else
  @preconcurrency import Glibc
#endif

public struct ConfirmationClient: Sendable {
  public var confirm: @Sendable (String) -> Bool

  public init(confirm: @escaping @Sendable (String) -> Bool) {
    self.confirm = confirm
  }
}

private enum ConfirmationClientKey: DependencyKey {
  static var liveValue: ConfirmationClient {
    ConfirmationClient(
      confirm: { prompt in
        Swift.print("\(prompt) ", terminator: "")
        fflush(stdout)
        guard let response = readLine(strippingNewline: true)?
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .lowercased()
        else {
          return false
        }
        return response == "y" || response == "yes"
      }
    )
  }

  static var testValue: ConfirmationClient {
    ConfirmationClient(confirm: { _ in true })
  }
}

public extension DependencyValues {
  var confirmationClient: ConfirmationClient {
    get { self[ConfirmationClientKey.self] }
    set { self[ConfirmationClientKey.self] = newValue }
  }
}
