import Foundation

public enum ObservationMode: String, Equatable, Sendable {
  case on
  case off
}

public struct ObservationSettings: Equatable, Sendable {
  public var mode: ObservationMode

  public init(mode: ObservationMode) {
    self.mode = mode
  }

  public static let `default` = ObservationSettings(
    mode: .on
  )
}
