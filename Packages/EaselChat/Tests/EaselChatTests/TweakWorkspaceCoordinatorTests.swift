import EaselKit
import Foundation
import Testing
@testable import EaselChat

@Suite("TweakWorkspaceCoordinator")
struct TweakWorkspaceCoordinatorTests {
  @Test func appliesGeneratedFileWhenTargetIsUnchanged() async throws {
    let fixture = try makeFixture(contents: "before")
    defer { try? FileManager.default.removeItem(at: fixture.rootURL) }
    let coordinator = TweakWorkspaceCoordinator(temporaryRootURL: fixture.temporaryURL)
    let transaction = try await coordinator.prepare(targetFileURL: fixture.targetURL)
    try Data("after".utf8).write(to: transaction.workingFileURL)

    let result = try await coordinator.finish(transaction)

    #expect(result == .applied)
    #expect(try String(contentsOf: fixture.targetURL, encoding: .utf8) == "after")
  }

  @Test func reportsNoChangesWithoutWritingTarget() async throws {
    let fixture = try makeFixture(contents: "before")
    defer { try? FileManager.default.removeItem(at: fixture.rootURL) }
    let coordinator = TweakWorkspaceCoordinator(temporaryRootURL: fixture.temporaryURL)
    let transaction = try await coordinator.prepare(targetFileURL: fixture.targetURL)

    let result = try await coordinator.finish(transaction)

    #expect(result == .noChanges)
    #expect(try String(contentsOf: fixture.targetURL, encoding: .utf8) == "before")
  }

  @Test func preservesConcurrentTargetEdit() async throws {
    let fixture = try makeFixture(contents: "before")
    defer { try? FileManager.default.removeItem(at: fixture.rootURL) }
    let coordinator = TweakWorkspaceCoordinator(temporaryRootURL: fixture.temporaryURL)
    let transaction = try await coordinator.prepare(targetFileURL: fixture.targetURL)
    try Data("agent edit".utf8).write(to: transaction.workingFileURL)
    try Data("main chat edit".utf8).write(to: fixture.targetURL)

    let result = try await coordinator.finish(transaction)

    #expect(result == .conflict)
    #expect(try String(contentsOf: fixture.targetURL, encoding: .utf8) == "main chat edit")
  }

  @Test func appliesNewPropsWithoutChangingExistingProps() async throws {
    let fixture = try makeFixture(contents: html(props: """
      "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 60 }
      """))
    defer { try? FileManager.default.removeItem(at: fixture.rootURL) }
    let coordinator = TweakWorkspaceCoordinator(temporaryRootURL: fixture.temporaryURL)
    let transaction = try await coordinator.prepare(targetFileURL: fixture.targetURL)
    let generated = html(props: """
      "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 60 },
      "nightMode": { "label": "Night Mode", "type": "toggle", "value": false }
      """)
    try Data(generated.utf8).write(to: transaction.workingFileURL)

    let result = try await coordinator.finish(transaction, policy: .additive)

    #expect(result == .applied)
    #expect(try String(contentsOf: fixture.targetURL, encoding: .utf8) == generated)
  }

  @Test func rejectsGeneratedFileThatRemovesExistingProps() async throws {
    let original = html(props: """
      "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 60 },
      "nightMode": { "label": "Night Mode", "type": "toggle", "value": false }
      """)
    let fixture = try makeFixture(contents: original)
    defer { try? FileManager.default.removeItem(at: fixture.rootURL) }
    let coordinator = TweakWorkspaceCoordinator(temporaryRootURL: fixture.temporaryURL)
    let transaction = try await coordinator.prepare(targetFileURL: fixture.targetURL)
    try Data(html(props: """
      "contrast": { "label": "Contrast", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 50 }
      """).utf8).write(to: transaction.workingFileURL)

    do {
      _ = try await coordinator.finish(transaction, policy: .additive)
      Issue.record("Expected generated tweaks validation to fail")
    } catch TweakWorkspaceError.invalidGeneratedTweaks {
      #expect(try String(contentsOf: fixture.targetURL, encoding: .utf8) == original)
    }
  }

  @Test func rejectsGeneratedFileThatMutatesExistingProps() async throws {
    let original = html(props: """
      "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 60 }
      """)
    let fixture = try makeFixture(contents: original)
    defer { try? FileManager.default.removeItem(at: fixture.rootURL) }
    let coordinator = TweakWorkspaceCoordinator(temporaryRootURL: fixture.temporaryURL)
    let transaction = try await coordinator.prepare(targetFileURL: fixture.targetURL)
    try Data(html(props: """
      "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 20 },
      "contrast": { "label": "Contrast", "type": "toggle", "value": false }
      """).utf8).write(to: transaction.workingFileURL)

    do {
      _ = try await coordinator.finish(transaction, policy: .additive)
      Issue.record("Expected generated tweaks validation to fail")
    } catch TweakWorkspaceError.invalidGeneratedTweaks {
      #expect(try String(contentsOf: fixture.targetURL, encoding: .utf8) == original)
    }
  }

  @Test func flexiblePolicyAllowsIntentionalExistingPropChanges() async throws {
    let original = html(props: """
      "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 60 }
      """)
    let fixture = try makeFixture(contents: original)
    defer { try? FileManager.default.removeItem(at: fixture.rootURL) }
    let coordinator = TweakWorkspaceCoordinator(temporaryRootURL: fixture.temporaryURL)
    let transaction = try await coordinator.prepare(targetFileURL: fixture.targetURL)
    let generated = html(props: """
      "warmth": { "label": "Warmth", "type": "slider", "min": 0, "max": 100, "step": 1, "value": 20 }
      """)
    try Data(generated.utf8).write(to: transaction.workingFileURL)

    let result = try await coordinator.finish(transaction, policy: .flexible)

    #expect(result == .applied)
    #expect(try String(contentsOf: fixture.targetURL, encoding: .utf8) == generated)
  }

  private func html(props: String) -> String {
    """
    <script>
      dc_set_props({
        \(props)
      });
      function render() {}
      dc_on_props_changed = render;
      render();
    </script>
    """
  }

  private func makeFixture(contents: String) throws -> Fixture {
    let rootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("TweakWorkspaceCoordinatorTests-\(UUID().uuidString)", isDirectory: true)
    let projectURL = rootURL.appendingPathComponent("project", isDirectory: true)
    let temporaryURL = rootURL.appendingPathComponent("tasks", isDirectory: true)
    try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
    let targetURL = projectURL.appendingPathComponent("index.html")
    try Data(contents.utf8).write(to: targetURL)
    return Fixture(rootURL: rootURL, temporaryURL: temporaryURL, targetURL: targetURL)
  }
}

private struct Fixture {
  let rootURL: URL
  let temporaryURL: URL
  let targetURL: URL
}
