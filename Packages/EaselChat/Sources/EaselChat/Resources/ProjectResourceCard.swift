//
//  ProjectResourceCard.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct ProjectResourceCard: View {
  let resource: ProjectResource
  let isSelected: Bool
  let onSelect: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Button(action: onSelect) {
      VStack(alignment: .leading, spacing: 12) {
        Color.clear
          .aspectRatio(16.0 / 9.0, contentMode: .fit)
          .overlay {
            ProjectFileThumbnailView(
              fileURL: resource.fileURL,
              kind: resource.kind,
              targetSize: CGSize(width: 320, height: 180),
              cornerRadius: 8,
              contentMode: .fill
            )
          }

        VStack(alignment: .leading, spacing: 8) {
          Text(resource.fileName)
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

          HStack(spacing: 6) {
            Text(resource.kind.displayName)
            Text(formattedByteCount)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(12)
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
      .overlay {
        if isSelected {
          RoundedRectangle(cornerRadius: 8)
            .stroke(
              EaselDesignSystem.Palette.selectionAccent(for: colorScheme),
              lineWidth: 2
            )
        } else {
          RoundedRectangle(cornerRadius: 8)
            .stroke(.quaternary, lineWidth: 1)
        }
      }
      .contentShape(RoundedRectangle(cornerRadius: 8))
      .clipped()
    }
    .frame(minWidth: 0, maxWidth: .infinity)
    .buttonStyle(.plain)
    .help("Preview \(resource.fileName)")
    .accessibilityValue(isSelected ? "Selected" : "")
  }

  private var formattedByteCount: String {
    ByteCountFormatter.string(fromByteCount: resource.byteCount, countStyle: .file)
  }
}
