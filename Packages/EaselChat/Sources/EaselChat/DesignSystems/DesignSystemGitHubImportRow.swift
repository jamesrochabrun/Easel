//
//  DesignSystemGitHubImportRow.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignSystemGitHubImportRow: View {
  @Bindable var viewModel: DesignSystemSetupViewModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 14) {
        Text("Link code on GitHub")
          .font(.title3.weight(.semibold))
          .frame(width: 260, alignment: .leading)

        TextField("https://github.com/owner/repo", text: $viewModel.sourceLinkDraft)
          .textFieldStyle(.plain)
          .font(.title3)
          .padding(.horizontal, 12)
          .frame(height: 42)
          .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
          .overlay {
            RoundedRectangle(cornerRadius: 8)
              .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
          }
          .onSubmit(viewModel.addSourceLink)

        Button("Add", action: viewModel.addSourceLink)
          .buttonStyle(.bordered)
          .controlSize(.large)
          .disabled(viewModel.sourceLinkDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }

      if !viewModel.sourceLinks.isEmpty {
        DesignSystemSelectedLinkList(
          links: viewModel.sourceLinks,
          onRemove: viewModel.removeSourceLink
        )
        .padding(.leading, 274)
      }
    }
  }
}
