//
//  DesignLibraryThumbnailPlaceholderView.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignLibraryThumbnailPlaceholderView: View {
  let item: DesignLibraryItem

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      background

      VStack(spacing: 12) {
        Image(systemName: item.kind.systemImage)
          .font(.system(size: 38, weight: .light))
          .foregroundStyle(iconColor)

        Text(item.kind.displayName)
          .font(EaselDesignSystem.Typography.interface(size: 13, weight: .medium))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .lineLimit(1)
      }
      .padding(18)
    }
  }

  private var background: some View {
    ZStack {
      EaselDesignSystem.Palette.surfaceElevated(for: colorScheme)

      if item.kind == .designSystem {
        Color(red: 0.95, green: 0.88, blue: 0.88)
          .opacity(colorScheme == .dark ? 0.18 : 0.72)
      }
    }
  }

  private var iconColor: Color {
    item.kind == .designSystem
      ? EaselDesignSystem.Palette.secondaryText(for: colorScheme)
      : EaselDesignSystem.Palette.tertiaryText(for: colorScheme)
  }
}
