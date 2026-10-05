import Foundation

/// Which CLI agent filed an artifact. Provenance only — Studio routing keys
/// on the project path, but the panel labels artifacts with their source.
///
/// Raw values are capitalized on the wire for display; `init(commandLineValue:)`
/// accepts the lowercase form the `EASEL_PROVIDER` environment variable uses.
public enum StudioProvider: String, Codable, CaseIterable, Equatable, Sendable {
  case claude = "Claude"
  case codex = "Codex"

  /// The lowercase form used on command lines and in environment variables.
  public var commandLineValue: String {
    rawValue.lowercased()
  }

  public init?(commandLineValue: String) {
    let normalized = commandLineValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch normalized {
    case "claude":
      self = .claude
    case "codex":
      self = .codex
    default:
      return nil
    }
  }
}
