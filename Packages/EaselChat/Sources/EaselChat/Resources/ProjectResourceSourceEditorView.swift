//
//  ProjectResourceSourceEditorView.swift
//  EaselChat
//

import AppKit
import CodeEditLanguages
import CodeEditSourceEditor
import SwiftUI

enum ProjectResourceEditorDisplayMode: Equatable {
  case highlighted
  case plainText

  private static let highlightedByteLimit = 300_000
  private static let highlightedLineLimit = 5_000
  private static let highlightedMaxLineByteLimit = 2_000

  var badgeLabel: String? {
    switch self {
    case .highlighted:
      nil
    case .plainText:
      "Fast Mode"
    }
  }

  var highlightsSyntax: Bool {
    self == .highlighted
  }

  var usesFullEditorFeatures: Bool {
    self == .highlighted
  }

  static func displayMode(for content: String) -> ProjectResourceEditorDisplayMode {
    displayMode(for: ProjectResourceTextFileMetrics.metrics(for: content))
  }

  static func displayMode(for metrics: ProjectResourceTextFileMetrics) -> ProjectResourceEditorDisplayMode {
    if metrics.byteCount <= highlightedByteLimit,
       metrics.lineCount <= highlightedLineLimit,
       metrics.maxLineByteCount <= highlightedMaxLineByteLimit {
      return .highlighted
    }

    return .plainText
  }
}

struct ProjectResourceSourceEditorView: View {
  @Binding var text: String
  let fileName: String
  let documentID: UUID
  let displayMode: ProjectResourceEditorDisplayMode
  var isEditable = true

  var body: some View {
    ProjectResourceSourceEditorHost(
      text: $text,
      fileName: fileName,
      displayMode: displayMode,
      isEditable: isEditable
    )
    .clipped()
    .id(documentID)
  }
}

private struct ProjectResourceSourceEditorHost: View {
  @Binding var text: String
  let fileName: String
  let displayMode: ProjectResourceEditorDisplayMode
  let isEditable: Bool

  @AppStorage("Easel.resources.sourceEditor.minimapEnabled")
  private var sourceEditorMinimapEnabled = true
  @AppStorage("Easel.resources.sourceEditor.wrapLinesEnabled")
  private var sourceEditorWrapLinesEnabled = true
  @Environment(\.colorScheme) private var colorScheme
  @State private var editorState = SourceEditorState()

  var body: some View {
    SourceEditor(
      $text,
      language: ProjectResourceSourceEditorLanguageResolver.language(
        forFileName: fileName,
        content: text,
        displayMode: displayMode
      ),
      configuration: editorOptions.makeSourceEditorConfiguration(colorScheme: colorScheme),
      state: $editorState,
      highlightProviders: highlightProviders
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var editorOptions: ProjectResourceSourceEditorOptions {
    ProjectResourceSourceEditorOptions(
      displayMode: displayMode,
      isEditable: isEditable,
      isMinimapEnabled: sourceEditorMinimapEnabled,
      isWrapLinesEnabled: sourceEditorWrapLinesEnabled
    )
  }

  private var highlightProviders: [any HighlightProviding]? {
    displayMode.highlightsSyntax ? nil : []
  }
}

struct ProjectResourceSourceEditorOptions {
  let displayMode: ProjectResourceEditorDisplayMode
  let isEditable: Bool
  let isMinimapEnabled: Bool
  let isWrapLinesEnabled: Bool

  let lineHeightMultiple: Double = 1.3
  let letterSpacing: Double = 1.0
  let tabWidth = 2
  let editorOverscroll: CGFloat = 0.2
  let additionalTextInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)

  var wrapLines: Bool {
    isWrapLinesEnabled && displayMode.usesFullEditorFeatures
  }

  var bracketPairEmphasis: BracketPairEmphasis? {
    displayMode.highlightsSyntax ? .flash : nil
  }

  var showMinimap: Bool {
    isMinimapEnabled && displayMode.usesFullEditorFeatures
  }

  var showFoldingRibbon: Bool {
    displayMode.usesFullEditorFeatures
  }

  func makeSourceEditorConfiguration(colorScheme: ColorScheme) -> SourceEditorConfiguration {
    SourceEditorConfiguration(
      appearance: .init(
        theme: ProjectResourceSourceEditorTheme.theme(for: colorScheme),
        useThemeBackground: true,
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        lineHeightMultiple: lineHeightMultiple,
        letterSpacing: letterSpacing,
        wrapLines: wrapLines,
        useSystemCursor: true,
        tabWidth: tabWidth,
        bracketPairEmphasis: bracketPairEmphasis
      ),
      behavior: .init(
        isEditable: isEditable,
        isSelectable: true,
        indentOption: .spaces(count: 2),
        reformatAtColumn: 100
      ),
      layout: .init(
        editorOverscroll: editorOverscroll,
        contentInsets: nil,
        additionalTextInsets: additionalTextInsets
      ),
      peripherals: .init(
        showGutter: true,
        showMinimap: showMinimap,
        showReformattingGuide: false,
        showFoldingRibbon: showFoldingRibbon
      )
    )
  }
}

enum ProjectResourceSourceEditorLanguageResolver {
  static func languageIdentifier(
    forFileName fileName: String,
    content: String,
    displayMode: ProjectResourceEditorDisplayMode
  ) -> String {
    language(forFileName: fileName, content: content, displayMode: displayMode).tsName
  }

  static func language(
    forFileName fileName: String,
    content: String,
    displayMode: ProjectResourceEditorDisplayMode
  ) -> CodeLanguage {
    guard displayMode.highlightsSyntax, !fileName.isEmpty else {
      return .default
    }

    return CodeLanguage.detectLanguageFrom(
      url: URL(fileURLWithPath: fileName),
      prefixBuffer: prefixBuffer(from: content),
      suffixBuffer: suffixBuffer(from: content)
    )
  }

  private static func prefixBuffer(from content: String, maxLines: Int = 8) -> String {
    guard !content.isEmpty else { return "" }
    var endIndex = content.startIndex
    var newlineCount = 0

    while endIndex < content.endIndex, newlineCount < maxLines {
      if content[endIndex].isNewline {
        newlineCount += 1
      }
      endIndex = content.index(after: endIndex)
    }

    return String(content[..<endIndex])
  }

  private static func suffixBuffer(from content: String, maxLines: Int = 8) -> String {
    guard !content.isEmpty else { return "" }
    var startIndex = content.endIndex
    var newlineCount = 0

    while startIndex > content.startIndex, newlineCount < maxLines {
      let previousIndex = content.index(before: startIndex)
      if content[previousIndex].isNewline {
        newlineCount += 1
        if newlineCount == maxLines {
          startIndex = content.index(after: previousIndex)
          break
        }
      }
      startIndex = previousIndex
    }

    return String(content[startIndex...])
  }
}

private enum ProjectResourceSourceEditorTheme {
  static func theme(for colorScheme: ColorScheme) -> EditorTheme {
    switch colorScheme {
    case .dark:
      darkTheme(resolvingIn: .darkAqua)
    case .light:
      lightTheme(resolvingIn: .aqua)
    @unknown default:
      lightTheme(resolvingIn: .aqua)
    }
  }

  private static func lightTheme(resolvingIn appearanceName: NSAppearance.Name) -> EditorTheme {
    EditorTheme(
      text: .init(color: rgb(.labelColor, resolvingIn: appearanceName)),
      insertionPoint: rgb(.controlAccentColor, resolvingIn: appearanceName),
      invisibles: .init(color: rgb(.tertiaryLabelColor, resolvingIn: appearanceName)),
      background: rgb(.textBackgroundColor, resolvingIn: appearanceName),
      lineHighlight: rgb(NSColor.black.withAlphaComponent(0.05), resolvingIn: appearanceName),
      selection: rgb(.selectedTextBackgroundColor, resolvingIn: appearanceName),
      keywords: .init(color: rgb(.systemPurple, resolvingIn: appearanceName)),
      commands: .init(color: rgb(.systemBlue, resolvingIn: appearanceName)),
      types: .init(color: rgb(.systemTeal, resolvingIn: appearanceName)),
      attributes: .init(color: rgb(.systemIndigo, resolvingIn: appearanceName)),
      variables: .init(color: rgb(.labelColor, resolvingIn: appearanceName)),
      values: .init(color: rgb(.systemMint, resolvingIn: appearanceName)),
      numbers: .init(color: rgb(.systemOrange, resolvingIn: appearanceName)),
      strings: .init(color: rgb(.systemRed, resolvingIn: appearanceName)),
      characters: .init(color: rgb(.systemPink, resolvingIn: appearanceName)),
      comments: .init(color: rgb(.secondaryLabelColor, resolvingIn: appearanceName), italic: true)
    )
  }

  private static func darkTheme(resolvingIn appearanceName: NSAppearance.Name) -> EditorTheme {
    EditorTheme(
      text: .init(color: rgb(.labelColor, resolvingIn: appearanceName)),
      insertionPoint: rgb(.controlAccentColor, resolvingIn: appearanceName),
      invisibles: .init(color: rgb(.tertiaryLabelColor, resolvingIn: appearanceName)),
      background: rgb(.windowBackgroundColor, resolvingIn: appearanceName),
      lineHighlight: rgb(NSColor.white.withAlphaComponent(0.08), resolvingIn: appearanceName),
      selection: rgb(.selectedTextBackgroundColor, resolvingIn: appearanceName),
      keywords: .init(color: rgb(.systemPurple, resolvingIn: appearanceName)),
      commands: .init(color: rgb(.systemBlue, resolvingIn: appearanceName)),
      types: .init(color: rgb(.systemTeal, resolvingIn: appearanceName)),
      attributes: .init(color: rgb(.systemIndigo, resolvingIn: appearanceName)),
      variables: .init(color: rgb(.labelColor, resolvingIn: appearanceName)),
      values: .init(color: rgb(.systemMint, resolvingIn: appearanceName)),
      numbers: .init(color: rgb(.systemOrange, resolvingIn: appearanceName)),
      strings: .init(color: rgb(.systemRed, resolvingIn: appearanceName)),
      characters: .init(color: rgb(.systemPink, resolvingIn: appearanceName)),
      comments: .init(color: rgb(.secondaryLabelColor, resolvingIn: appearanceName), italic: true)
    )
  }

  private static func rgb(_ color: NSColor, resolvingIn appearanceName: NSAppearance.Name) -> NSColor {
    guard let appearance = NSAppearance(named: appearanceName) else {
      return color.usingColorSpace(.sRGB) ?? color
    }

    var resolvedColor = color
    appearance.performAsCurrentDrawingAppearance {
      resolvedColor = color.usingColorSpace(.sRGB) ?? color
    }
    return resolvedColor
  }
}
