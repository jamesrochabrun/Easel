import Foundation
import Testing

struct SidebarViewSourceTests {
  @Test
  func projectNameFieldUsesReadableInputTint() throws {
    let source = try sourceContents("Sources/EaselChat/Sidebar/SidebarView.swift")

    #expect(source.contains(".tint(EaselDesignSystem.Palette.selectionAccent(for: colorScheme))"))
  }

  @Test
  func headerUsesEaselMenuBarAsset() throws {
    let source = try sourceContents("Sources/EaselChat/Sidebar/SidebarView.swift")

    #expect(source.contains("Image(\"easelmenubar\")"))
    #expect(!source.contains("Image(systemName: \"sparkles\")"))
  }

  @Test
  func headerIconUsesDarkModeTintAndVisualTextAlignment() throws {
    let source = try sourceContents("Sources/EaselChat/Sidebar/SidebarView.swift")

    #expect(source.contains("HStack(alignment: .center, spacing: 5)"))
    #expect(source.contains(".frame(width: 16, height: 16)"))
    #expect(!source.contains(".offset(y:"))
    #expect(source.contains("colorScheme == .dark ? .white : EaselDesignSystem.Palette.accent"))
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
