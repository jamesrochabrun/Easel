//
//  LocalAgentHandoffSection.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct LocalAgentHandoffSection<Content: View>: View {
  let title: String
  let subtitle: String?
  let isOptional: Bool
  let content: Content

  @Environment(\.colorScheme) private var colorScheme

  init(
    title: String,
    subtitle: String? = nil,
    isOptional: Bool = false,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.subtitle = subtitle
    self.isOptional = isOptional
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        header

        if let subtitle {
          Text(subtitle)
            .font(.callout)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      content
    }
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.primary)

      if isOptional {
        Text("(optional)")
          .font(.subheadline)
          .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}
