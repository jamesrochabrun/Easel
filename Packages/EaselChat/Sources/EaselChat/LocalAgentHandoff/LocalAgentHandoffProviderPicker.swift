//
//  LocalAgentHandoffProviderPicker.swift
//  EaselChat
//

import ClaudeCodeCore
import SwiftUI

struct LocalAgentHandoffProviderPicker: View {
  @Bindable var viewModel: LocalAgentHandoffViewModel

  var body: some View {
    Picker("Agent", selection: $viewModel.selectedProvider) {
      ForEach(LocalAgentProvider.allCases) { provider in
        Text(provider.displayName)
          .tag(provider)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
  }
}
