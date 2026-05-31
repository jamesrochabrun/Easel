//
//  AppStateProtocol.swift
//  EaselKit
//

import Foundation

@MainActor
public protocol AppStateProtocol: AnyObject {
  var phase: AppPhase { get }
  var promptText: String { get set }
  func submitPrompt()
  func resetToCapsule()
  func openCanvas()
}
