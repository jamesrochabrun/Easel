import Foundation

/// Records which files the model has read (and the modification time observed
/// at read) so mutating tools can enforce read-before-modify and detect files
/// that changed on disk after they were read.
///
/// Keys are fully resolved absolute paths (as produced by
/// `PathConfinementPolicy.resolveForRead/resolveForWrite`) so `Read`, `Write`,
/// and `Edit` agree on identity regardless of how the model spelled the path.
public actor FileReadRegistry {

  private var modificationDates: [String: Date] = [:]

  public init() {}

  /// Records that `path` was read (or rewritten) while its on-disk
  /// modification date was `modificationDate`.
  public func recordRead(path: String, modificationDate: Date) {
    modificationDates[path] = modificationDate
  }

  /// Whether `path` has ever been read (or written) through the tool set.
  public func hasRead(_ path: String) -> Bool {
    modificationDates[path] != nil
  }

  /// The on-disk modification date observed the last time `path` was read or
  /// rewritten, or `nil` if it was never read.
  public func modificationDateAtRead(for path: String) -> Date? {
    modificationDates[path]
  }
}
