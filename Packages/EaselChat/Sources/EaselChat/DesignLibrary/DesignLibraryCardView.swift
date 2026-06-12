//
//  DesignLibraryCardView.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignLibraryCardView: View {
  let item: DesignLibraryItem
  @Bindable var thumbnailCache: DesignLibraryThumbnailCache
  @Bindable var paletteCache: DesignLibraryPaletteCache

  @State private var isHovering = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      DesignLibraryThumbnailView(item: item, thumbnailCache: thumbnailCache, paletteCache: paletteCache)

      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
          Text(item.title)
            .font(EaselDesignSystem.Typography.interface(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Spacer(minLength: 8)

          DesignLibraryKindBadge(kind: item.kind, gradientColors: badgeGradientColors)
        }

        HStack(spacing: 8) {
          Label(item.kind.displayName, systemImage: item.kind.systemImage)
            .labelStyle(.iconOnly)
            .font(.caption.weight(.medium))
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .accessibilityHidden(true)

          Text(relativeActivityDescription)
            .font(EaselDesignSystem.Typography.interface(size: 13, weight: .medium))
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .lineLimit(1)

          Spacer(minLength: 0)

          if item.latestSession != nil {
            Text("Session")
              .font(EaselDesignSystem.Typography.interface(size: 12, weight: .medium))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .padding(.horizontal, 7)
              .frame(height: 20)
              .background(
                EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
                in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
              )
          }
        }
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(EaselDesignSystem.Palette.surface(for: colorScheme))
    }
    .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .stroke(cardBorderColor, lineWidth: isHovering ? 1.5 : 1)
    }
    .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.05), radius: isHovering ? 10 : 4, y: isHovering ? 4 : 2)
    .contentShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.12)) {
        isHovering = hovering
      }
    }
  }

  /// Accent gradient for the "Design system" badge chip, derived from the
  /// system's palette once its tokens have loaded.
  private var badgeGradientColors: [Color] {
    guard item.kind == .designSystem,
          let tokens = paletteCache.tokens(for: item.workingDirectory),
          !tokens.colors.isEmpty else {
      return []
    }
    return DesignSystemPaletteGradient.accentColors(from: tokens.colors)
  }

  private var cardBorderColor: Color {
    isHovering
      ? EaselDesignSystem.Palette.selectionAccent(for: colorScheme).opacity(0.55)
      : EaselDesignSystem.Palette.border(for: colorScheme)
  }

  private var relativeActivityDescription: String {
    let interval = max(0, Date().timeIntervalSince(item.activityDate))

    if interval < 60 {
      return "Updated now"
    }

    if interval < 3600 {
      let minutes = max(1, Int(interval / 60))
      return "Updated \(minutes)m ago"
    }

    if interval < 86400 {
      let hours = max(1, Int(interval / 3600))
      return "Updated \(hours)h ago"
    }

    if interval < 604800 {
      let days = max(1, Int(interval / 86400))
      return "Updated \(days)d ago"
    }

    return item.activityDate.formatted(.dateTime.month(.abbreviated).day())
  }
}
