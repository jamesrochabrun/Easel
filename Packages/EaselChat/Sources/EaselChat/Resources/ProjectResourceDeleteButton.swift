//
//  ProjectResourceDeleteButton.swift
//  EaselChat
//

import SwiftUI

/// A compact, high-contrast trash button revealed on hover over a resource so
/// deletion is discoverable without relying on the right-click context menu.
struct ProjectResourceDeleteButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "trash.fill")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 24, height: 24)
        .background(Circle().fill(Color.black.opacity(0.55)))
        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
    }
    .buttonStyle(.plain)
  }
}
