//
//  AppState.swift
//  Easel
//

import Foundation

// MARK: - AppPhase

enum AppPhase: Equatable {
  case capsule
  case canvas
}

// MARK: - AppStateProtocol

@MainActor
protocol AppStateProtocol: AnyObject {
  var phase: AppPhase { get }
  var promptText: String { get set }
  func submitPrompt()
  func resetToCapsule()
}

// MARK: - AppState

@Observable @MainActor
final class AppState: AppStateProtocol {
  var phase: AppPhase = .capsule
  var promptText: String = ""

  func submitPrompt() {
    let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    phase = .canvas
  }

  func resetToCapsule() {
    phase = .capsule
  }
}
