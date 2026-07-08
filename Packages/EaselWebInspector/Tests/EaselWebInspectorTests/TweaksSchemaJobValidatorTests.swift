//
//  TweaksSchemaJobValidatorTests.swift
//  EaselWebInspectorTests
//

import EaselKit
import Foundation
import Testing
@testable import EaselWebInspector

struct TweaksSchemaJobValidatorTests {

  private let validSource = """
    <html>
    <body>
    <script>
      dc_set_props({
        "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 60 },
        "night": { "label": "Night mode", "type": "toggle", "value": false }
      });
      function render() {}
      dc_on_props_changed = render;
      render();
    </script>
    </body>
    </html>
    """

  private func makeShadow(files: [String: String]) throws -> URL {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("validator-tests-\(UUID().uuidString)")
    for (relativePath, content) in files {
      let url = root.appendingPathComponent(relativePath)
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      try content.write(to: url, atomically: true, encoding: .utf8)
    }
    return root
  }

  @Test
  func validatesSchemaInTargetFile() async throws {
    let shadow = try makeShadow(files: ["index.html": validSource])
    defer { try? FileManager.default.removeItem(at: shadow) }

    let outcome = try await TweaksSchemaJobValidator().validate(
      shadowRoot: shadow.path,
      targetRelativePath: "index.html",
      changedFiles: ["index.html"]
    )

    #expect(outcome.schemaFileRelativePath == "index.html")
    #expect(outcome.propNames == ["warmth", "night"])
  }

  @Test
  func fallsBackToChangedComponentFile() async throws {
    // Dev-server projects: the agent instrumented a component, not index.html.
    let shadow = try makeShadow(files: [
      "index.html": "<html><body>plain</body></html>",
      "src/App.tsx": validSource,
    ])
    defer { try? FileManager.default.removeItem(at: shadow) }

    let outcome = try await TweaksSchemaJobValidator().validate(
      shadowRoot: shadow.path,
      targetRelativePath: "index.html",
      changedFiles: ["index.html", "src/App.tsx"]
    )

    #expect(outcome.schemaFileRelativePath == "src/App.tsx")
  }

  @Test
  func throwsWhenNoSchemaAnywhere() async throws {
    let shadow = try makeShadow(files: [
      "index.html": "<html><body>no props here</body></html>",
      "src/App.tsx": "export const App = () => null",
    ])
    defer { try? FileManager.default.removeItem(at: shadow) }

    await #expect(throws: TweaksSchemaValidationError.self) {
      _ = try await TweaksSchemaJobValidator().validate(
        shadowRoot: shadow.path,
        targetRelativePath: "index.html",
        changedFiles: ["index.html", "src/App.tsx"]
      )
    }
  }

  @Test
  func throwsWhenTargetFileMissingAndNoChangedFileParses() async throws {
    let shadow = try makeShadow(files: [:])
    defer { try? FileManager.default.removeItem(at: shadow) }

    await #expect(throws: TweaksSchemaValidationError.self) {
      _ = try await TweaksSchemaJobValidator().validate(
        shadowRoot: shadow.path,
        targetRelativePath: "index.html",
        changedFiles: []
      )
    }
  }
}
