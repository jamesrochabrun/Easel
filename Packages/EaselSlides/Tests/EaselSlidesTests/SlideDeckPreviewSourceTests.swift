//
//  SlideDeckPreviewSourceTests.swift
//  EaselSlidesTests
//

import Foundation
import Testing

struct SlideDeckPreviewSourceTests {
  @Test
  func previewFramesUseSquareClipping() throws {
    let source = try sourceContents(
      "Sources/EaselSlides/Views/SlideDeckPreviewView.swift"
    )

    #expect(source.contains(".clipped()"))
    #expect(source.contains("Rectangle()\n            .stroke"))
    #expect(source.contains("RoundedRectangle(cornerRadius: 3)") == false)
  }

  @Test
  func previewDefersRepresentableCallbackStateUpdates() throws {
    let source = try sourceContents(
      "Sources/EaselSlides/Views/SlideDeckPreviewView.swift"
    )

    #expect(source.contains("onLoadingChange: handleLoadingChange"))
    #expect(source.contains("onError: handleError"))
    #expect(source.contains("Task { @MainActor in"))
    #expect(source.contains("onLoadingChange: { isLoading = $0 }") == false)
    #expect(source.contains("onError: { errorMessage = $0 }") == false)
  }

  @Test
  func presentationFramesUseSquareClipping() throws {
    let source = try sourceContents(
      "Sources/EaselSlides/Views/SlideDeckPresentationView.swift"
    )

    #expect(source.contains(".clipped()"))
  }

  @Test
  func presentationDefersRepresentableCallbackStateUpdates() throws {
    let source = try sourceContents(
      "Sources/EaselSlides/Views/SlideDeckPresentationView.swift"
    )

    #expect(source.contains("onLoadingChange: handleLoadingChange"))
    #expect(source.contains("onError: handleError"))
    #expect(source.contains("Task { @MainActor in"))
    #expect(source.contains("onLoadingChange: { isLoading = $0 }") == false)
    #expect(source.contains("onError: { errorMessage = $0 }") == false)
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
