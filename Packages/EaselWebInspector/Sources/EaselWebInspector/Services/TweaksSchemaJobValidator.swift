//
//  TweaksSchemaJobValidator.swift
//  EaselWebInspector
//
//  Validates a background tweaks job's shadow output: the target file (or,
//  failing that, one of the changed files — dev-server projects may get
//  instrumented in a component instead of index.html) must declare a
//  parseable, non-empty dc_set_props schema before the job can apply.
//

import Canvas
import EaselKit
import Foundation

// MARK: - TweaksSchemaValidationError

public enum TweaksSchemaValidationError: LocalizedError {
  case noSchemaFound

  public var errorDescription: String? {
    "The generated changes don't declare any tweakable props"
  }
}

// MARK: - TweaksSchemaJobValidator

public struct TweaksSchemaJobValidator: BackgroundJobValidating {

  public init() {}

  public func validate(
    shadowRoot: String,
    targetRelativePath: String,
    changedFiles: [String]
  ) async throws -> BackgroundJobValidationOutcome {
    var candidates = [targetRelativePath]
    candidates.append(contentsOf: changedFiles.filter { $0 != targetRelativePath })

    let shadowURL = URL(fileURLWithPath: shadowRoot)
    for relativePath in candidates {
      let fileURL = shadowURL.appendingPathComponent(relativePath)
      guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
      guard let names = try? TweakPropsSourceEditor.parsePropNames(fromSource: source),
            !names.isEmpty,
            let props = try? TweakPropsSourceEditor.parseProps(fromSource: source),
            !props.isEmpty else {
        continue
      }
      return BackgroundJobValidationOutcome(schemaFileRelativePath: relativePath, propNames: names)
    }

    throw TweaksSchemaValidationError.noSchemaFound
  }
}
