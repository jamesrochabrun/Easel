import AppKit
import EaselKit
import SwiftUI
import Testing

@testable import EaselChat

private final class FindPanelHostingView: NSView {}

private func withCurrentDrawingAppearance<T>(_ name: NSAppearance.Name, _ body: () -> T) -> T {
  guard let appearance = NSAppearance(named: name) else { return body() }

  var result: T?
  appearance.performAsCurrentDrawingAppearance {
    result = body()
  }
  return result ?? body()
}

private func brightness(of color: NSColor) -> CGFloat {
  (color.usingColorSpace(.sRGB) ?? color).brightnessComponent
}

private func hexString(of color: Color) -> String {
  let resolvedColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
  let red = Int(round(resolvedColor.redComponent * 255))
  let green = Int(round(resolvedColor.greenComponent * 255))
  let blue = Int(round(resolvedColor.blueComponent * 255))
  return String(format: "#%02X%02X%02X", red, green, blue)
}

@Suite("SourceCodeEditorView")
struct SourceCodeEditorViewTests {
  @Test
  func displayModeHighlightsNormalFiles() {
    let content = Array(repeating: "let value = 1", count: 1_000).joined(separator: "\n")

    #expect(EditorDisplayMode.displayMode(for: content) == .highlighted)
  }

  @Test
  func displayModeUsesFastModeForLargeFiles() {
    let largeByteContent = String(repeating: "a", count: 300_001)
    let largeLineContent = Array(repeating: "line", count: 5_001).joined(separator: "\n")
    let longLineContent = String(repeating: "a", count: 2_001)

    #expect(EditorDisplayMode.displayMode(for: largeByteContent) == .plainText)
    #expect(EditorDisplayMode.displayMode(for: largeLineContent) == .plainText)
    #expect(EditorDisplayMode.displayMode(for: longLineContent) == .plainText)
  }

  @Test
  func textFileMetricsTrackLargestLine() {
    let metrics = TextFileMetrics.metrics(for: "abc\nabcdef\nz")

    #expect(metrics.byteCount == 12)
    #expect(metrics.lineCount == 3)
    #expect(metrics.maxLineByteCount == 6)
  }

  @Test
  func editorOptionsToggleMinimapAndWrappingByMode() {
    let highlighted = EaselSourceEditorOptions(
      displayMode: .highlighted,
      isEditable: true,
      isMinimapEnabled: true,
      isWrapLinesEnabled: true
    )
    let plainText = EaselSourceEditorOptions(
      displayMode: .plainText,
      isEditable: true,
      isMinimapEnabled: true,
      isWrapLinesEnabled: true
    )

    #expect(highlighted.showMinimap)
    #expect(highlighted.wrapLines)
    #expect(highlighted.showFoldingRibbon)
    #expect(plainText.showMinimap == false)
    #expect(plainText.wrapLines == false)
    #expect(plainText.showFoldingRibbon == false)
  }

  @Test
  func editorThemeResolvesColorsFromRequestedColorScheme() {
    let options = EaselSourceEditorOptions(
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
  func textPreviewHeaderStyleResolvesColorsFromRequestedColorScheme() {
    let lightStyle = ProjectResourceTextPreviewStyle(colorScheme: .light)
    let darkStyle = ProjectResourceTextPreviewStyle(colorScheme: .dark)

    #expect(hexString(of: lightStyle.editorBackground) == EaselDesignSystem.Palette.surfaceLightHex)
    #expect(hexString(of: lightStyle.headerBackground) == EaselDesignSystem.Palette.surfaceElevatedLightHex)
    #expect(hexString(of: lightStyle.headerSecondaryText) == EaselDesignSystem.Palette.textSecondaryLightHex)
    #expect(hexString(of: lightStyle.headerBorder) == EaselDesignSystem.Palette.borderLightHex)
    #expect(hexString(of: darkStyle.editorBackground) == "#12171C")
    #expect(hexString(of: darkStyle.headerBackground) == "#171C21")
    #expect(hexString(of: darkStyle.headerSecondaryText) == EaselDesignSystem.Palette.textSecondaryDarkHex)
  }

  @Test
  func languageResolverDetectsSupportedFiles() {
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
        SourceEditorLanguageResolver.languageIdentifier(
          forFileName: testCase.fileName,
          content: "",
          displayMode: .highlighted
        ) == testCase.expectedIdentifier
      )
    }
  }

  @Test
  func languageResolverFallsBackToPlainTextForFastMode() {
    #expect(
      SourceEditorLanguageResolver.languageIdentifier(
        forFileName: "App.swift",
        content: "let value = 1",
        displayMode: .plainText
      ) == "PlainText"
    )
  }

  @Test
  func findPanelRepairBringsCodeEditFindPanelToFront() {
    let rootView = NSView()
    let codeEditContainer = NSView()
    let findPanel = FindPanelHostingView()
    let editorScrollView = NSScrollView()

    rootView.addSubview(codeEditContainer)
    codeEditContainer.addSubview(findPanel)
    codeEditContainer.addSubview(editorScrollView)

    let didRepair = SourceEditorFindPanelHitTestingFix.bringFindPanelToFront(in: rootView)

    #expect(didRepair)
    #expect(codeEditContainer.subviews.last === findPanel)
    #expect(findPanel.layer?.zPosition == 1000)
  }

  @Test
  func findNavigatorAdvancesAndWrapsThroughMatches() {
    let text = "provider\nlet providerValue = provider"
    let matches = SourceEditorFindNavigator.matchRanges(query: "provider", in: text)

    #expect(matches.map(\.location) == [0, 13, 29])
    #expect(
      SourceEditorFindNavigator.targetRange(
        matches: matches,
        currentRange: matches[0],
        direction: .next
      ) == matches[1]
    )
    #expect(
      SourceEditorFindNavigator.targetRange(
        matches: matches,
        currentRange: matches[2],
        direction: .next
      ) == matches[0]
    )
  }
}
