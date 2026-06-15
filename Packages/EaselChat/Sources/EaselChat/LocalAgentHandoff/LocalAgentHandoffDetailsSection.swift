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
    LocalAgentHandoffSection(
      title: "Give the agent more detail on what to implement",
      isOptional: true
    ) {
      TextField(
        LocalAgentHandoffPromptBuilder.defaultDetails,
        text: $viewModel.details,
        axis: .vertical
      )
      .textFieldStyle(.plain)
      .font(.body)
      .lineLimit(3...6)
      .padding(14)
      .frame(minHeight: 96, alignment: .topLeading)
      .background(
        EaselDesignSystem.Palette.surface(for: colorScheme),
        in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
      )
      .overlay {
        RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }
    }
  }
}
