import Foundation
import Testing

struct ChatPanelViewSourceTests {
  @Test
  func chatScreenIdentityTracksCurrentViewModel() throws {
    let source = try sourceContents("Sources/EaselChat/ChatPanelView.swift")

    #expect(source.contains(".id(ObjectIdentifier(vm))"))
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
