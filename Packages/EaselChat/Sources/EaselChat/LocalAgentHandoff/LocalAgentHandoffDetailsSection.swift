//
//  LocalAgentHandoffDetailsSection.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct LocalAgentHandoffDetailsSection: View {
  @Bindable var viewModel: LocalAgentHandoffViewModel

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    LocalAgentHandoffSection(title: "Implement") {
      TextField(
        LocalAgentHandoffPromptBuilder.defaultDetails,
        text: $viewModel.details,
        axis: .vertical
      )
      .textFieldStyle(.plain)
      .font(.title3)
      .lineLimit(4...)
      .padding(18)
      .frame(minHeight: 118, alignment: .topLeading)
      .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }
    }
  }
}
