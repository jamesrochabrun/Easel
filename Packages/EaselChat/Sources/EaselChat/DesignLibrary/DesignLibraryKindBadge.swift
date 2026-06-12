//
//  DesignLibraryKindBadge.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignLibraryKindBadge: View {
  let kind: DesignLibraryItemKind
  /// When supplied (design systems), a gradient chip built from the system's
  /// palette replaces the generic SF Symbol icon.
  var gradientColors: [Color] = []

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 6) {
      leadingMark

      Text(kind.displayName)
        .font(EaselDesignSystem.Typography.interface(size: 12, weight: .medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .lineLimit(1)
    }
    .padding(.horizontal, 8)
    .frame(height: 24)
    .background(
      colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
      in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
    )
  }

  @ViewBuilder
  private var leadingMark: some View {
    if gradientColors.count >= 2 {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(
          LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 14, height: 14)
        .overlay(
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
        )
    } else {
      Image(systemName: kind.systemImage)
        .font(EaselDesignSystem.Typography.interface(size: 12, weight: .medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
    }
  }
}
