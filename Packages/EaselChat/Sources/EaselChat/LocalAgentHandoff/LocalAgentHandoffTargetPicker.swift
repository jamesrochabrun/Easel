//
//  LocalAgentHandoffTargetPicker.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct LocalAgentHandoffTargetPicker: View {
  @Bindable var viewModel: LocalAgentHandoffViewModel
  let context: LocalAgentHandoffContext?
  let onSelectRepository: () -> Void
  let onCreateProject: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Picker("Target", selection: $viewModel.selectedTarget) {
        ForEach(availableTargets) { target in
          Text(target.displayName)
            .tag(target)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      LocalAgentHandoffTargetDetail(
        target: viewModel.selectedTarget,
        codebasePath: context?.codebasePath,
        selectedRepositoryPath: viewModel.selectedRepositoryPath,
        createdProjectPath: viewModel.createdProjectPath,
        isCreatingProject: viewModel.isCreatingProject,
        canCreateProject: viewModel.canCreateProject(context: context),
        onSelectRepository: onSelectRepository,
        onCreateProject: onCreateProject
      )
    }
  }

  private var availableTargets: [LocalAgentHandoffTarget] {
    LocalAgentHandoffTarget.availableTargets(hasCodebase: context?.codebasePath != nil)
  }
}
