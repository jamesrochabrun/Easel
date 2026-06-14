//
//  WebPreviewModeButton.swift
//  EaselWebInspector
//

import EaselKit
import SwiftUI

struct WebPreviewModeButton: View {
  let title: String
  let systemImage: String
  let isActive: Bool
  let width: CGFloat
  let height: CGFloat
  let font: Font
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  init(
    title: String,
    systemImage: String,
    isActive: Bool,
    width: CGFloat,
    height: CGFloat,
    font: Font,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.systemImage = systemImage
    self.isActive = isActive
    self.width = width
    self.height = height
    self.font = font
    self.action = action
  }

  var body: some View {
    let appearance = WebPreviewModeButtonAppearance.resolve(isActive: isActive)

    Button(action: action) {
      ZStack {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
          .fill(appearance.backgroundColor(for: colorScheme))

        Image(systemName: systemImage)
          .font(font)
          .foregroundStyle(appearance.iconColor(for: colorScheme))
      }
      .frame(width: width, height: height)
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
          .stroke(appearance.borderColor(for: colorScheme), lineWidth: isActive ? 1 : 0)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityValue(appearance.accessibilityValue)
  }
}
