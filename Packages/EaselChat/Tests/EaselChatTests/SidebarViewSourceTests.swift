import Foundation
import Testing

struct SidebarViewSourceTests {
  @Test
  func projectNameFieldUsesReadableInputTint() throws {
    let source = try sourceContents("Sources/EaselChat/Sidebar/SidebarView.swift")

    #expect(source.contains(".tint(EaselDesignSystem.Palette.selectionAccent(for: colorScheme))"))
  }

  private func sourceContents(_ relativePath: String) throws -> String {
    let testsDirectory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let packageDirectory = testsDirectory.deletingLastPathComponent()
    return try String(
      contentsOf: packageDirectory.appendingPathComponent(relativePath),
      encoding: .utf8
    )
  }
}
