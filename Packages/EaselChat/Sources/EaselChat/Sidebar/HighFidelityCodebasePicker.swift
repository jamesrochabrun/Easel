//
//  HighFidelityCodebasePicker.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct HighFidelityCodebasePicker: View {
  let codebasePath: String?
  let onSelect: () -> Void
  let onClear: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Codebase")
          .font(.callout.weight(.medium))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        Spacer()

        Button(selectButtonTitle, systemImage: "folder.badge.plus", action: onSelect)
          .font(.caption.weight(.medium))
          .buttonStyle(.plain)
          .foregroundStyle(EaselDesignSystem.Palette.accent)
          .help("Select codebase")
      }

      if let codebasePath {
        HStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(EaselDesignSystem.Palette.accent)
            .accessibilityHidden(true)

          Text(codebasePath)
            .font(.caption)
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .lineLimit(1)
            .truncationMode(.middle)
            .help(codebasePath)

          Spacer()

          Button("Remove", systemImage: "xmark.circle", action: onClear)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
            .help("Remove codebase")
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(
          EaselDesignSystem.Palette.subtleSurface(for: colorScheme),
          in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
        )
        .overlay {
          RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
        .accessibilityLabel("Selected codebase \(codebasePath)")
      }
    }
  }

  private var selectButtonTitle: String {
    codebasePath == nil ? "Select" : "Change"
  }
}
