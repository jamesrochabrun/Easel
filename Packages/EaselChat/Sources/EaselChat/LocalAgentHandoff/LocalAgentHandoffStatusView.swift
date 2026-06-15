//
//  LocalAgentHandoffStatusView.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct LocalAgentHandoffStatusView: View {
  let errorMessage: String?
  let successMessage: String?

  var body: some View {
    if let errorMessage {
      Label(errorMessage, systemImage: "exclamationmark.triangle")
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.danger)
        .fixedSize(horizontal: false, vertical: true)
    } else if let successMessage {
      Label(successMessage, systemImage: "checkmark.circle.fill")
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.accent)
    }
  }
}
