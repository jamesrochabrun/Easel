//
//  WebPreviewConsoleView.swift
//  EaselWebInspector
//
//  Displays captured console output from the inspected web view.
//

import EaselKit
import SwiftUI

public struct WebPreviewConsoleView: View {
  let entries: [String]
  let onClear: () -> Void
  @Environment(\.colorScheme) private var colorScheme

  public init(entries: [String], onClear: @escaping () -> Void) {
    self.entries = entries
    self.onClear = onClear
  }

  public var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Console")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Button("Clear", action: onClear)
          .buttonStyle(.plain)
          .font(.system(size: 11, weight: .semibold))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(EaselDesignSystem.Palette.surface(for: colorScheme))

      if entries.isEmpty {
        ContentUnavailableView(
          "No Console Output",
          systemImage: "terminal",
          description: Text("Console logs, warnings, and errors from the preview will appear here.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(Array(entries.enumerated()), id: \.offset) { pair in
              let entry = pair.element
              Text(entry)
                .font(.system(size: 11, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(
                  RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
                    .fill(EaselDesignSystem.Palette.surface(for: colorScheme))
                )
                .overlay {
                  RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
                    .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
                }
            }
          }
          .padding(12)
        }
      }
    }
  }
}
