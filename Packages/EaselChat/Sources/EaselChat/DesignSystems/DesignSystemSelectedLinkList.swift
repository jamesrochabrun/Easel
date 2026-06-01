//
//  DesignSystemSelectedLinkList.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignSystemSelectedLinkList: View {
  let links: [String]
  let onRemove: (String) -> Void
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(links, id: \.self) { link in
        HStack(spacing: 8) {
          Image(systemName: "link")
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

          Text(link)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.middle)

          Spacer()

          Button {
            onRemove(link)
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
