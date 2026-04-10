//
//  WebPreviewUpdateBar.swift
//  EaselWebInspector
//
//  Bottom update bar for the web preview inspector rail.
//

import SwiftUI

public struct WebPreviewUpdateBar: View {
  let state: WebPreviewUpdateState
  let onUpdate: () -> Void

  public init(state: WebPreviewUpdateState, onUpdate: @escaping () -> Void) {
    self.state = state
    self.onUpdate = onUpdate
  }

  public var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Reload")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.primary)

        Text(state.detailText)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }

      Spacer()

      Button(action: onUpdate) {
        HStack(spacing: 8) {
          Text("Reload")

          Text("\u{2318}\u{21A9}")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
              Capsule()
                .fill(Color.secondary.opacity(0.15))
            )
        }
      }
      .webPreviewPrimaryButtonStyle()
      .disabled(!state.isEnabled)
      .help("Update preview")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color.surfaceElevated)
    .overlay(alignment: .top) {
      Divider()
    }
  }
}
