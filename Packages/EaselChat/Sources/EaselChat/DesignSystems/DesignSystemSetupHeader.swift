//
//  DesignSystemSetupHeader.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignSystemSetupHeader: View {
  let onCancel: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack {
      Text("Create Design System")
        .font(EaselDesignSystem.Typography.interface(size: 18, weight: .semibold))

      Spacer()

      Button("Close", systemImage: "xmark", action: onCancel)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .help("Close")
    }
    .padding(.horizontal, 22)
    .padding(.vertical, 16)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)
    }
  }
}
