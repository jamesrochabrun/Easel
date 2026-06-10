//
//  DesignLibraryKindBadge.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignLibraryKindBadge: View {
  let kind: DesignLibraryItemKind

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Label(kind.displayName, systemImage: kind.systemImage)
      .font(EaselDesignSystem.Typography.interface(size: 12, weight: .medium))
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .lineLimit(1)
      .padding(.horizontal, 8)
      .frame(height: 24)
      .background(
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06),
        in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
      )
  }
}
