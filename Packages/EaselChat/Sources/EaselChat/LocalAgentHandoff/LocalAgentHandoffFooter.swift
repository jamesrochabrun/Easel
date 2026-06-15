//
//  LocalAgentHandoffFooter.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct LocalAgentHandoffFooter: View {
  let isLaunching: Bool
  let canLaunch: Bool
  let onCancel: () -> Void
  let onStart: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack {
      Spacer()

      Button("Cancel", action: onCancel)
        .keyboardShortcut(.cancelAction)

      Button(action: onStart) {
        Label(isLaunching ? "Starting" : "Start in Terminal", systemImage: isLaunching ? "hourglass" : "terminal")
      }
      .buttonStyle(.borderedProminent)
      .keyboardShortcut(.defaultAction)
      .disabled(!canLaunch)
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 18)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
    .overlay(alignment: .top) {
      Rectangle()
        .fill(EaselDesignSystem.Palette.border(for: colorScheme))
        .frame(height: 1)
    }
  }
}
