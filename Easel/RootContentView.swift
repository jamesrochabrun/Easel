//
//  RootContentView.swift
//  Easel
//

import EaselKit
import SwiftUI

struct RootContentView: View {
  @Bindable var appState: AppState

  var body: some View {
    Group {
      switch appState.phase {
      case .capsule:
        CapsuleInputView(appState: appState)
          .transition(.opacity.combined(with: .scale(scale: 0.95)))

      case .canvas:
        CanvasContentView(appState: appState)
          .transition(.opacity.combined(with: .scale(scale: 0.95)))
      }
    }
    .animation(.spring(duration: 0.5, bounce: 0.12), value: appState.phase)
  }
}
