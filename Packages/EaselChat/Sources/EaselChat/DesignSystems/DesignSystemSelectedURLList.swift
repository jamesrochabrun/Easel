//
//  DesignSystemSelectedURLList.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignSystemSelectedURLList: View {
  let urls: [URL]
  let onRemove: (URL) -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(urls, id: \.self) { url in
        HStack(spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(EaselDesignSystem.Palette.success)

          Text(url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.middle)

          Spacer()

          Button {
            onRemove(url)
          } label: {
            Image(systemName: "xmark")
              .font(.caption.weight(.semibold))
          }
          .buttonStyle(.plain)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .help("Remove")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: 6))
      }
    }
  }
}
