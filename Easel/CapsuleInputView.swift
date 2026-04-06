//
//  CapsuleInputView.swift
//  Easel
//

import SwiftUI

struct CapsuleInputView: View {
  @Bindable var appState: AppState
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "sparkles")
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 20)

      TextField("What would you like to build?", text: $appState.promptText)
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
    .onAppear {
      isFocused = true
    }
  }

  private var canSubmit: Bool {
    !appState.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
