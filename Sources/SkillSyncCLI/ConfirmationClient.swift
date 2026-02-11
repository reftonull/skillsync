import Dependencies
import Foundation

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
        let promptData = Data("\(prompt) ".utf8)
        FileHandle.standardOutput.write(promptData)
        guard
          let response = readLine(strippingNewline: true)?
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
