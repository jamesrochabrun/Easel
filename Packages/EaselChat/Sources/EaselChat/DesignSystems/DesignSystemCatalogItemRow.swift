//
//  DesignSystemCatalogItemRow.swift
//  EaselChat
//

import EaselKit
import EaselDesignSystems
import SwiftUI

struct DesignSystemCatalogItemRow: View {
  let item: EaselDesignSystemComponentItem
  let onUseStartingPoint: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(item.title)
          .font(.callout.weight(.semibold))
        Text(item.summary)
          .font(.callout)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer()

      Button("Use", systemImage: "arrow.turn.down.right", action: onUseStartingPoint)
        .buttonStyle(.bordered)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
  }
}
