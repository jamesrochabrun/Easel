//
//  ProjectResourceTextPreview.swift
//  EaselChat
//

import HighlightSwift
import SwiftUI

struct ProjectResourceTextPreview: View {
  let item: ProjectResourcePanelItem
  let text: String
  let languageMapper: any ProjectResourceCodeLanguageMapping

  init(
    item: ProjectResourcePanelItem,
    text: String,
    languageMapper: any ProjectResourceCodeLanguageMapping = ProjectResourceCodeLanguageMapper()
  ) {
    self.item = item
    self.text = text
    self.languageMapper = languageMapper
  }

  var body: some View {
    Group {
      if text.isEmpty {
        emptyState
      } else {
        codePreview
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(editorBackground)
  }

  private var codePreview: some View {
    VStack(spacing: 0) {
      languageHeader

      ScrollView([.horizontal, .vertical], showsIndicators: true) {
        CodeText(text)
          .highlightMode(languageMapper.highlightMode(forFileName: item.fileName))
          .codeTextColors(.theme(.tokyoNight))
          .font(codeFont)
          .textSelection(.enabled)
          .padding(.horizontal, 18)
          .padding(.vertical, 16)
          .fixedSize(horizontal: true, vertical: true)
      }
      .background(editorBackground)
    }
  }

  private var languageHeader: some View {
    HStack(spacing: 8) {
      Text(languageDisplayName.uppercased())
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary)

      Spacer(minLength: 8)
    }
    .frame(height: 32)
    .padding(.horizontal, 14)
    .background(editorHeaderBackground)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.white.opacity(0.08))
        .frame(height: 1)
    }
  }

  private var emptyState: some View {
    Text("Empty file")
      .font(.system(size: 13, design: .monospaced))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var codeFont: Font {
    .system(size: 13, weight: .regular, design: .monospaced)
  }

  private var languageDisplayName: String {
    languageMapper.displayName(forFileName: item.fileName) ?? "text"
  }

  private var editorBackground: Color {
    Color(red: 0.07, green: 0.09, blue: 0.11)
  }

  private var editorHeaderBackground: Color {
    Color(red: 0.09, green: 0.11, blue: 0.13)
  }
}
