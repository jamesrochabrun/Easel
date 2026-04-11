//
//  AppState.swift
//  EaselKit
//

import Foundation

@Observable @MainActor
public final class AppState: AppStateProtocol {
  public var phase: AppPhase = .capsule
  public var promptText: String = ""
  public var selectedProjectURL: URL?

  public init() {}

  public func submitPrompt() {
    let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    phase = .canvas
  }

  public func resetToCapsule() {
    phase = .capsule
  }

  public func openCanvas() {
    phase = .canvas
  }
}
