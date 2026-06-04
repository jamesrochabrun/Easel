//
//  ProjectStructureRow.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct ProjectStructureRow: View {
  let item: ProjectStructureItem
  let isSelected: Bool
  let onSelect: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 10) {
        ProjectFileThumbnailView(
          fileURL: item.fileURL,
          kind: item.kind,
          targetSize: CGSize(width: 38, height: 38),
          cornerRadius: 6,
          contentMode: .fit
        )
        .frame(width: 38, height: 38)

        VStack(alignment: .leading, spacing: 2) {
          Text(item.fileName)
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.middle)

          HStack(spacing: 6) {
            Text(item.relativePath)
              .lineLimit(1)
              .truncationMode(.middle)

            Text(formattedByteCount)
              .lineLimit(1)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 7)
      .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(
            isSelected ? EaselDesignSystem.Palette.selectionAccent(for: colorScheme) : .clear,
            lineWidth: 1
          )
      }
      .contentShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .help("Preview \(item.relativePath)")
    .accessibilityValue(isSelected ? "Selected" : "")
  }

  private var rowBackground: some ShapeStyle {
    isSelected
      ? EaselDesignSystem.Palette.selectedSurface(for: colorScheme)
      : Color.clear
  }

  private var formattedByteCount: String {
    ByteCountFormatter.string(fromByteCount: item.byteCount, countStyle: .file)
  }
}
