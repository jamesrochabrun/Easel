//
//  BackgroundJobValidating.swift
//  EaselKit
//
//  Feature-specific validation of a finished job's shadow output, injected
//  into the job service so it stays agnostic of feature parsers (the tweaks
//  validator uses Canvas's dc_set_props parser, which EaselChat can't see).
//

import Foundation

// MARK: - BackgroundJobValidationOutcome

public struct BackgroundJobValidationOutcome: Sendable, Equatable {
  /// Project-relative path of the file that carries the validated schema.
  public let schemaFileRelativePath: String
  /// Names of the props the schema declares.
  public let propNames: [String]

  public init(schemaFileRelativePath: String, propNames: [String]) {
    self.schemaFileRelativePath = schemaFileRelativePath
    self.propNames = propNames
  }
}

// MARK: - BackgroundJobValidating

public protocol BackgroundJobValidating: Sendable {
  /// Validates the job's output inside the shadow workspace. Throws with a
  /// user-facing message when the output is unusable.
  func validate(
    shadowRoot: String,
    targetRelativePath: String,
    changedFiles: [String]
  ) async throws -> BackgroundJobValidationOutcome
}
