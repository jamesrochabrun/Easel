//
//  DesignLibraryErrorBanner.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignLibraryErrorBanner: View {
  let message: String

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Label(message, systemImage: "exclamationmark.triangle")
      .font(EaselDesignSystem.Typography.interface(size: 13, weight: .medium))
      .foregroundStyle(EaselDesignSystem.Palette.danger)
      .lineLimit(3)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        EaselDesignSystem.Palette.danger.opacity(colorScheme == .dark ? 0.18 : 0.10),
        in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
      )
  }
}
