//
//  CanvasWorkspaceEmptyState.swift
//  Easel
//

import EaselKit
import SwiftUI

struct CanvasWorkspaceEmptyState: View {
  let content: CanvasWorkspaceEmptyStateContent
  let action: () -> Void

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ContentUnavailableView {
      Label(content.title, systemImage: content.systemImage)
    } description: {
      Text(content.message)
    } actions: {
      Button(content.actionTitle, systemImage: content.actionSystemImage, action: action)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
  }
}

enum CanvasWorkspaceEmptyStateContent: Equatable {
  case noDesigns
  case noSelection

  static func resolve(currentWorkingDirectory: String?, designCount: Int?) -> Self? {
    if let currentWorkingDirectory,
       !currentWorkingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return nil
    }

    if designCount == 0 {
      return .noDesigns
    }

    return .noSelection
  }

  var title: String {
    switch self {
    case .noDesigns:
      return "No designs yet"
    case .noSelection:
      return "No design selected"
    }
  }

  var message: String {
    switch self {
    case .noDesigns:
      return "Create a prototype, slide deck, animation, or design system to start working."
    case .noSelection:
      return "Select an existing design or create a new one before sending a message."
    }
  }

  var systemImage: String {
    switch self {
    case .noDesigns:
      return "square.grid.2x2"
    case .noSelection:
      return "rectangle.inset.filled"
    }
  }

  var actionTitle: String {
    switch self {
    case .noDesigns:
      return "Show Create Controls"
    case .noSelection:
      return "Browse Designs"
    }
  }

  var actionSystemImage: String {
    switch self {
    case .noDesigns:
      return "sidebar.left"
    case .noSelection:
      return "square.grid.2x2"
    }
  }
}
