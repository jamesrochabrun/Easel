//
//  FigmaLocalFileHelpPopover.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct FigmaLocalFileHelpPopover: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("How to download a .fig file")
        .font(.title2.weight(.semibold))
        .foregroundStyle(.primary)

      VStack(alignment: .leading, spacing: 10) {
        Text("From the Figma web or desktop app:")
          .font(.title3)

        Text("1. Open the file in Figma.")
        Text("2. Go to File -> Save local copy... (web: main menu -> File).")
        Text("3. Figma downloads a .fig file. Drop it onto the chat input.")
      }
      .font(.title3)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .lineSpacing(4)

      Text("The file is parsed locally in your browser and never uploaded.")
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
    }
    .padding(24)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }
}
