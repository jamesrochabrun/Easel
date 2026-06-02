import EaselKit
import HighlightSwift
import MarkdownUI
import SwiftUI

struct EaselMarkdownMessageView: View {
  let content: String
  let role: MessageRole
  let fontSize: CGFloat
  let isComplete: Bool
  let fillsAvailableWidth: Bool
  let showArtifact: ((Artifact) -> Void)?
  let renderer: any ChatMarkdownRendering
  let languageMapper: any ChatMarkdownCodeLanguageMapping

  @Environment(AppearanceSettings.self) private var appearanceSettings
  @Environment(\.colorScheme) private var colorScheme

  init(
    content: String,
    role: MessageRole,
    fontSize: CGFloat,
    isComplete: Bool = true,
    fillsAvailableWidth: Bool = true,
    showArtifact: ((Artifact) -> Void)? = nil,
    renderer: any ChatMarkdownRendering = DefaultChatMarkdownRenderer(),
    languageMapper: any ChatMarkdownCodeLanguageMapping = ChatMarkdownCodeLanguageMapper()
  ) {
    self.content = content
    self.role = role
    self.fontSize = fontSize
    self.isComplete = isComplete
    self.fillsAvailableWidth = fillsAvailableWidth
    self.showArtifact = showArtifact
    self.renderer = renderer
    self.languageMapper = languageMapper
  }

  var body: some View {
    if fillsAvailableWidth {
      markdown
        .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      markdown
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var markdown: some View {
    Markdown(renderer.displayMarkdown(for: content, isComplete: isComplete))
      .markdownTheme(theme)
      .textSelection(.enabled)
  }

  private var theme: Theme {
    .easelChat(
      role: role,
      fontSize: fontSize,
      colorScheme: colorScheme,
      themeColors: appearanceSettings.themeColors,
      showArtifact: showArtifact,
      languageMapper: languageMapper
    )
  }
}

extension Theme {
  static func easelChat(
    role: MessageRole,
    fontSize: CGFloat,
    colorScheme: ColorScheme,
    themeColors: ThemeColors,
    showArtifact: ((Artifact) -> Void)?,
    languageMapper: any ChatMarkdownCodeLanguageMapping
  ) -> Theme {
    let colors = EaselMarkdownThemeColors(
      role: role,
      colorScheme: colorScheme,
      themeColors: themeColors
    )

    return Theme()
      .text {
        FontSize(fontSize)
        ForegroundColor(colors.primaryText)
      }
      .paragraph { configuration in
        configuration.label
          .lineSpacing(3)
          .markdownMargin(top: .zero, bottom: .em(0.55))
      }
      .heading1 { configuration in
        configuration.label
          .markdownTextStyle {
            FontWeight(.semibold)
            FontSize(.em(1.28))
          }
          .markdownMargin(top: .em(0.45), bottom: .em(0.28))
      }
      .heading2 { configuration in
        configuration.label
          .markdownTextStyle {
            FontWeight(.semibold)
            FontSize(.em(1.18))
          }
          .markdownMargin(top: .em(0.42), bottom: .em(0.24))
      }
      .heading3 { configuration in
        configuration.label
          .markdownTextStyle {
            FontWeight(.semibold)
            FontSize(.em(1.08))
          }
          .markdownMargin(top: .em(0.36), bottom: .em(0.2))
      }
      .heading4 { configuration in
        configuration.label
          .markdownTextStyle {
            FontWeight(.semibold)
          }
          .markdownMargin(top: .em(0.32), bottom: .em(0.16))
      }
      .heading5 { configuration in
        configuration.label
          .markdownTextStyle {
            FontWeight(.medium)
          }
          .markdownMargin(top: .em(0.28), bottom: .em(0.14))
      }
      .heading6 { configuration in
        configuration.label
          .markdownTextStyle {
            FontWeight(.medium)
            ForegroundColor(colors.secondaryText)
          }
          .markdownMargin(top: .em(0.24), bottom: .em(0.12))
      }
      .code {
        FontFamilyVariant(.monospaced)
        FontSize(.em(0.92))
        BackgroundColor(colors.inlineCodeBackground)
        ForegroundColor(colors.primaryText)
      }
      .codeBlock { configuration in
        EaselMarkdownCodeBlockView(
          code: configuration.content,
          language: configuration.language,
          colors: colors,
          showArtifact: showArtifact,
          languageMapper: languageMapper
        )
        .markdownMargin(top: .em(0.35), bottom: .em(0.65))
      }
      .blockquote { configuration in
        HStack(alignment: .top, spacing: 8) {
          RoundedRectangle(cornerRadius: 1.5)
            .fill(colors.quoteBar)
            .frame(width: 3)

          configuration.label
            .markdownTextStyle {
              ForegroundColor(colors.secondaryText)
              FontStyle(.italic)
            }
        }
        .padding(.vertical, 2)
        .markdownMargin(top: .em(0.25), bottom: .em(0.45))
      }
      .link {
        ForegroundColor(colors.link)
        UnderlineStyle(.single)
      }
      .listItem { configuration in
        configuration.label
          .markdownMargin(top: .em(0.08), bottom: .em(0.08))
      }
      .thematicBreak {
        Rectangle()
          .fill(colors.border)
          .frame(height: 1)
          .markdownMargin(top: .em(0.6), bottom: .em(0.6))
      }
      .table { configuration in
        configuration.label
          .markdownTableBorderStyle(.init(color: colors.border, width: 1))
          .markdownMargin(top: .em(0.35), bottom: .em(0.55))
      }
      .tableCell { configuration in
        configuration.label
          .markdownTextStyle {
            FontSize(.em(0.95))
          }
          .padding(.vertical, 5)
          .padding(.horizontal, 7)
      }
  }
}

private struct EaselMarkdownCodeBlockView: View {
  let code: String
  let language: String?
  let colors: EaselMarkdownThemeColors
  let showArtifact: ((Artifact) -> Void)?
  let languageMapper: any ChatMarkdownCodeLanguageMapping

  var body: some View {
    VStack(spacing: 0) {
      header

      ScrollView(.horizontal, showsIndicators: true) {
        CodeText(code)
          .highlightMode(languageMapper.highlightMode(for: language))
          .codeTextColors(colors.codeTextColors)
          .font(EaselChatRuntimeStyle.Typography.code(size: 12.5))
          .textSelection(.enabled)
          .padding(12)
          .fixedSize(horizontal: true, vertical: true)
      }
      .background(colors.codeBackground)
    }
    .clipShape(RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.compactRadius, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: EaselChatRuntimeStyle.compactRadius, style: .continuous)
        .strokeBorder(colors.border, lineWidth: 1)
    )
  }

  private var header: some View {
    HStack(spacing: 8) {
      if let displayName = languageMapper.displayName(for: language) {
        Text(displayName)
          .font(EaselChatRuntimeStyle.Typography.code(size: 11.5))
          .foregroundStyle(colors.secondaryText)
      }

      Spacer(minLength: 8)

      if let showArtifact,
         languageMapper.isMermaid(language) {
        Button {
          showArtifact(.diagram(code))
        } label: {
          Label("View", systemImage: "flowchart")
            .font(EaselChatRuntimeStyle.Typography.secondaryBody)
        }
        .buttonStyle(.plain)
        .foregroundStyle(colors.link)
        .help("View Mermaid diagram")
      }

      CopyButton(textToCopy: code, iconSize: 12, color: colors.secondaryText)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(colors.codeHeaderBackground)
  }
}

private struct EaselMarkdownThemeColors {
  let primaryText: Color
  let secondaryText: Color
  let link: Color
  let border: Color
  let inlineCodeBackground: Color
  let codeHeaderBackground: Color
  let codeBackground: Color
  let codeTextColors: CodeTextColors
  let quoteBar: Color

  init(role: MessageRole, colorScheme: ColorScheme, themeColors: ThemeColors) {
    switch role {
    case .user:
      let userText = EaselChatRuntimeStyle.userMessageText(for: colorScheme, themeColors: themeColors)
      primaryText = userText
      secondaryText = userText.opacity(0.78)
      link = userText
      border = userText.opacity(0.18)
      inlineCodeBackground = userText.opacity(0.14)
      codeHeaderBackground = userText.opacity(0.11)
      codeBackground = Color.black.opacity(colorScheme == .dark ? 0.22 : 0.14)
      codeTextColors = .custom(dark: .dark(.github), light: .dark(.github))
      quoteBar = userText.opacity(0.55)
    default:
      primaryText = .primary
      secondaryText = EaselChatRuntimeStyle.secondaryText(for: colorScheme, themeColors: themeColors)
      link = EaselDesignSystem.Palette.accentForeground(for: colorScheme)
      border = EaselChatRuntimeStyle.border(for: colorScheme, themeColors: themeColors)
      inlineCodeBackground = EaselChatRuntimeStyle.subtleCardBackground(for: colorScheme, themeColors: themeColors)
      codeHeaderBackground = EaselChatRuntimeStyle.cardBackground(for: colorScheme, themeColors: themeColors)
      codeBackground = EaselChatRuntimeStyle.subtleCardBackground(for: colorScheme, themeColors: themeColors)
      codeTextColors = .theme(.github)
      quoteBar = themeColors.brandPrimary.opacity(colorScheme == .dark ? 0.75 : 0.65)
    }
  }
}
