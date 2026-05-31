//
//  CapsuleInputView.swift
//  Easel
//

import EaselKit
import SwiftUI

struct CapsuleInputView: View {
  @Bindable var appState: AppState
  var onDismiss: () -> Void = {}
  @FocusState private var isFocused: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    HStack(spacing: 12) {
      TextField("Describe the prototype you want to build", text: $appState.promptText)
        .textFieldStyle(.plain)
        .font(EaselDesignSystem.Typography.interface(size: 15))
        .foregroundStyle(.primary)
        .focused($isFocused)
        .onSubmit {
          appState.submitPrompt()
        }

      Button(action: { appState.submitPrompt() }) {
        Image(systemName: "arrow.up")
          .font(EaselDesignSystem.Typography.interface(size: 13, weight: .bold))
          .foregroundStyle(sendIconColor)
          .frame(width: 32, height: 32)
          .background(sendButtonBackground, in: Circle())
      }
      .buttonStyle(.plain)
      .disabled(!canSubmit)
      .help("Create prototype")
    }
    .padding(.leading, 20)
    .padding(.trailing, 12)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      ZStack {
        GlassBackgroundView(material: .hudWindow)
        EaselDesignSystem.Palette.surface(for: colorScheme)
          .opacity(colorScheme == .dark ? 0.72 : 0.84)
      }
    }
    .clipShape(Capsule())
    .overlay {
      Capsule()
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
    .tint(EaselDesignSystem.Palette.accent)
    .onExitCommand(perform: onDismiss)
    .onAppear {
      isFocused = true
    }
  }

  private var canSubmit: Bool {
    !appState.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var sendButtonBackground: Color {
    canSubmit
      ? EaselDesignSystem.Palette.primaryAction(for: colorScheme)
      : EaselDesignSystem.Palette.subtleSurface(for: colorScheme)
  }

  private var sendIconColor: Color {
    canSubmit
      ? EaselDesignSystem.Palette.primaryActionForeground(for: colorScheme)
      : EaselDesignSystem.Palette.tertiaryText(for: colorScheme)
  }
}
