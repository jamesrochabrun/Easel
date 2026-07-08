import Foundation

/// Hardware gating for on-device inference.
public enum MLXAvailability {

  public enum ModelSizeTier: Int, Sendable, Comparable {
    /// Up to ~4B parameters at 4-bit.
    case small = 1
    /// Up to ~8B parameters at 4-bit.
    case medium = 2
    /// Up to ~15B parameters at 4-bit.
    case large = 3
    /// Bigger than ~15B parameters at 4-bit.
    case extraLarge = 4

    public static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }

  public struct Availability: Sendable, Equatable {
    public let isSupported: Bool
    public let unsupportedReason: String?
    public let physicalMemoryBytes: UInt64
    public let recommendedMaxTier: ModelSizeTier
  }

  public static func check() -> Availability {
    check(physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory, isAppleSilicon: isAppleSilicon)
  }

  /// Pure, testable core.
  static func check(physicalMemoryBytes: UInt64, isAppleSilicon: Bool) -> Availability {
    guard isAppleSilicon else {
      return Availability(
        isSupported: false,
        unsupportedReason: "On-device models require a Mac with Apple Silicon.",
        physicalMemoryBytes: physicalMemoryBytes,
        recommendedMaxTier: .small
      )
    }
    let gigabytes = Double(physicalMemoryBytes) / 1_073_741_824
    let tier: ModelSizeTier
    switch gigabytes {
    case ..<16: tier = .small
    case ..<32: tier = .medium
    case ..<64: tier = .large
    default: tier = .extraLarge
    }
    return Availability(
      isSupported: true,
      unsupportedReason: nil,
      physicalMemoryBytes: physicalMemoryBytes,
      recommendedMaxTier: tier
    )
  }

  static var isAppleSilicon: Bool {
    #if arch(arm64)
    return true
    #else
    return false
    #endif
  }
}
