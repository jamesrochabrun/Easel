//
//  DesignLibraryHeaderView.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignLibraryHeaderView: View {
  let itemCount: Int
  let isLoading: Bool
  let showsFilters: Bool
  let selectedKinds: Set<DesignLibraryItemKind>
  let kindCounts: [DesignLibraryItemKind: Int]
  let onToggleKind: (DesignLibraryItemKind) -> Void
  let onRefresh: () async -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 12) {
      Label("Designs", systemImage: "square.grid.2x2")
        .font(EaselDesignSystem.Typography.interface(size: 16, weight: .semibold))
        .foregroundStyle(.primary)

      if itemCount > 0 {
        Text("\(itemCount)")
          .font(EaselDesignSystem.Typography.interface(size: 12, weight: .semibold))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .padding(.horizontal, 8)
          .frame(height: 22)
          .background(
            EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
          )
      }

      if showsFilters {
        filterChips
      }

      Spacer()

      Button(action: refresh) {
        Label("Refresh designs", systemImage: "arrow.clockwise")
          .labelStyle(.iconOnly)
          .font(.system(size: 13, weight: .medium))
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .disabled(isLoading)
      .help("Refresh designs")
    }
    .padding(.horizontal, 22)
    .frame(height: EaselDesignSystem.Spacing.toolbarHeight)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  @ViewBuilder
  private var filterChips: some View {
    HStack(spacing: 6) {
      ForEach(DesignLibraryItemKind.allCases) { kind in
        DesignLibraryFilterChip(
          kind: kind,
          count: kindCounts[kind] ?? 0,
          isSelected: selectedKinds.contains(kind),
          action: { onToggleKind(kind) }
        )
      }
    }
    .padding(.leading, 4)
  }

  private func refresh() {
    Task {
      await onRefresh()
    }
  }
}
