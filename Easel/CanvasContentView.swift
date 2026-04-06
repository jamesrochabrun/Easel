//
//  CanvasContentView.swift
//  Easel
//

import SwiftUI

struct CanvasContentView: View {
  @Bindable var appState: AppState

  var body: some View {
    VStack(spacing: 0) {
      // Top bar with prompt
      HStack {
        Image(systemName: "sparkles")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.secondary)

        Text(appState.promptText)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
      .background(.ultraThinMaterial)

      Divider()
        .opacity(0.3)

      // Canvas area placeholder
      VStack(spacing: 16) {
        Spacer()

        Image(systemName: "rectangle.on.rectangle.angled")
          .font(.system(size: 40, weight: .thin))
          .foregroundStyle(.tertiary)

        Text("Canvas")
          .font(.system(size: 20, weight: .medium))
          .foregroundStyle(.secondary)

        Text("Your workspace is ready")
          .font(.system(size: 13))
          .foregroundStyle(.tertiary)

        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(GlassBackgroundView(material: .sidebar))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}
