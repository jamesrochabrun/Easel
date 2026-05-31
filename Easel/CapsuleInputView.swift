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

  var body: some View {
    HStack(spacing: 12) {
      TextField("Describe the prototype you want to build", text: $appState.promptText)
        .textFieldStyle(.plain)
        .font(.system(size: 16, weight: .regular))
        .focused($isFocused)
        .onSubmit {
          appState.submitPrompt()
        }

      Button(action: { appState.submitPrompt() }) {
        Image(systemName: "arrow.up.circle.fill")
          .font(.system(size: 24, weight: .medium))
          .foregroundStyle(canSubmit ? .white : .secondary)
      }
      .buttonStyle(.plain)
      .disabled(!canSubmit)
    }
    .padding(.horizontal, 18)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(GlassBackgroundView(material: .hudWindow))
    .clipShape(Capsule())
    .onExitCommand(perform: onDismiss)
    .onAppear {
      isFocused = true
    }
  }

  private var canSubmit: Bool {
    !appState.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
