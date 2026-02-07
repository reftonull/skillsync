import Foundation

public enum ObservationMode: String, Equatable, Sendable {
  case auto
  case remind
  case off
}

public struct ObservationSettings: Equatable, Sendable {
  public var mode: ObservationMode
  public var threshold: Double
  public var minInvocations: Int

  public init(mode: ObservationMode, threshold: Double, minInvocations: Int) {
    self.mode = mode
    self.threshold = threshold
    self.minInvocations = minInvocations
  }

  public static let `default` = ObservationSettings(
    mode: .auto,
    threshold: 0.3,
    minInvocations: 5
  )
}
