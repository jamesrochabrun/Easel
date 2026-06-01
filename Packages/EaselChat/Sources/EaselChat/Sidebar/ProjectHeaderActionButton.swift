//
//  ProjectHeaderActionButton.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct ProjectHeaderActionButton: View {
  let title: String
  let systemImage: String
  var role: ButtonRole? = nil
  let foregroundColor: Color
  let hoverColor: Color
  let action: () -> Void

  @State private var isHovering = false

  var body: some View {
    Button(role: role, action: action) {
      Label(title, systemImage: systemImage)
        .labelStyle(.iconOnly)
        .font(.caption.weight(.medium))
        .foregroundStyle(foregroundColor)
        .frame(width: 24, height: 24)
        .background(
          isHovering ? hoverColor : Color.clear,
          in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control)
        )
        .contentShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.control))
    }
    .buttonStyle(.plain)
    .help(title)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.12)) {
        isHovering = hovering
      }
    }
  }
}
