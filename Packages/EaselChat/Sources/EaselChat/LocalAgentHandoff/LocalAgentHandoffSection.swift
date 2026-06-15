//
//  LocalAgentHandoffSection.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct LocalAgentHandoffSection<Content: View>: View {
  let title: String
  let content: Content

  @Environment(\.colorScheme) private var colorScheme

  init(
    title: String,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.callout.weight(.medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      content
    }
  }
}
