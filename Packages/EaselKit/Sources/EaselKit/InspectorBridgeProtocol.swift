//
//  InspectorBridgeProtocol.swift
//  EaselKit
//

import Foundation

public enum InspectorTweakResult: Equatable, Sendable {
  case applied
  case noChanges
  case conflict
}

@MainActor
public protocol InspectorBridgeProtocol: AnyObject {
  func sendInspectorPrompt(_ prompt: String)
  func sendContextPrompt(_ prompt: String)
  func sendCropPrompt(_ prompt: String)
  func runTweakAgent(prompt: String, targetFileURL: URL) async throws -> InspectorTweakResult
}
