//
//  ProjectResourceSourceEditorViewTests.swift
//  EaselChatTests
//

import AppKit
import SwiftUI
import Testing
@testable import EaselChat

private func withCurrentDrawingAppearance<T>(_ name: NSAppearance.Name, _ body: () -> T) -> T {
  guard let appearance = NSAppearance(named: name) else {
    return body()
  }

  var result: T?
  appearance.performAsCurrentDrawingAppearance {
    result = body()
  }
  return result ?? body()
}

private func brightness(of color: NSColor) -> CGFloat {
  (color.usingColorSpace(.sRGB) ?? color).brightnessComponent
}

struct ProjectResourceSourceEditorViewTests {
  @Test
  func displayModeHighlightsNormalSourceFiles() {
    let content = Array(repeating: "let value = 1", count: 1_000).joined(separator: "\n")

    #expect(ProjectResourceEditorDisplayMode.displayMode(for: content) == .highlighted)
  }

  @Test
  func displayModeUsesPlainTextForLargeFiles() {
    let largeByteContent = String(repeating: "a", count: 300_001)
    let largeLineContent = Array(repeating: "line", count: 5_001).joined(separator: "\n")
    let longLineContent = String(repeating: "a", count: 2_001)

    #expect(ProjectResourceEditorDisplayMode.displayMode(for: largeByteContent) == .plainText)
    #expect(ProjectResourceEditorDisplayMode.displayMode(for: largeLineContent) == .plainText)
    #expect(ProjectResourceEditorDisplayMode.displayMode(for: longLineContent) == .plainText)
  }

  @Test
  func textFileMetricsTrackBytesLinesAndLargestLine() {
    let metrics = ProjectResourceTextFileMetrics.metrics(for: "abc\nabcdef\nz")

    #expect(metrics.byteCount == 12)
    #expect(metrics.lineCount == 3)
    #expect(metrics.maxLineByteCount == 6)
  }

  @Test
  func editorOptionsToggleWrappingAndPeripheralsByDisplayMode() {
    let highlighted = ProjectResourceSourceEditorOptions(
      displayMode: .highlighted,
      isEditable: true,
      isMinimapEnabled: true,
      isWrapLinesEnabled: true
    )
    let plainText = ProjectResourceSourceEditorOptions(
      displayMode: .plainText,
      isEditable: false,
      isMinimapEnabled: true,
      isWrapLinesEnabled: true
    )

    #expect(highlighted.letterSpacing == 1.0)
    #expect(highlighted.wrapLines)
    #expect(highlighted.showMinimap)
    #expect(highlighted.showFoldingRibbon)
    #expect(plainText.wrapLines == false)
    #expect(plainText.showMinimap == false)
    #expect(plainText.showFoldingRibbon == false)
  }

  @Test
  func editorThemeResolvesColorsFromRequestedColorScheme() {
    let options = ProjectResourceSourceEditorOptions(
      displayMode: .highlighted,
      isEditable: true,
      isMinimapEnabled: true,
      isWrapLinesEnabled: true
    )

    let lightThemeCreatedInDarkAppearance = withCurrentDrawingAppearance(.darkAqua) {
      options.makeSourceEditorConfiguration(colorScheme: .light).appearance.theme
    }
    let darkThemeCreatedInLightAppearance = withCurrentDrawingAppearance(.aqua) {
      options.makeSourceEditorConfiguration(colorScheme: .dark).appearance.theme
    }

    #expect(brightness(of: lightThemeCreatedInDarkAppearance.background) > 0.8)
    #expect(brightness(of: lightThemeCreatedInDarkAppearance.text.color) < 0.3)
    #expect(brightness(of: darkThemeCreatedInLightAppearance.background) < 0.3)
    #expect(brightness(of: darkThemeCreatedInLightAppearance.text.color) > 0.7)
  }

  @Test
  func languageResolverDetectsGeneratedCodeFileTypes() {
    let cases: [(fileName: String, expectedIdentifier: String)] = [
      ("App.swift", "swift"),
      ("Component.tsx", "typescript"),
      ("package.json", "json"),
      ("README.md", "markdown"),
      ("Dockerfile", "dockerfile"),
      ("site.yaml", "yaml"),
    ]

    for testCase in cases {
      #expect(
        ProjectResourceSourceEditorLanguageResolver.languageIdentifier(
          forFileName: testCase.fileName,
          content: "",
          displayMode: .highlighted
        ) == testCase.expectedIdentifier
      )
    }
  }

  @Test
  func languageResolverUsesShebangsAndFallsBackForFastMode() {
    #expect(
      ProjectResourceSourceEditorLanguageResolver.languageIdentifier(
        forFileName: "script",
        content: "#!/usr/bin/env python3\nprint('hello')",
        displayMode: .highlighted
      ) == "python"
    )
    #expect(
      ProjectResourceSourceEditorLanguageResolver.languageIdentifier(
        forFileName: "App.swift",
        content: "let value = 1",
        displayMode: .plainText
      ) == "PlainText"
    )
  }
}
