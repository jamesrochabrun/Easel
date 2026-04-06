//
//  InspectorBridgeProtocol.swift
//  EaselKit
//

@MainActor
public protocol InspectorBridgeProtocol: AnyObject {
  func sendInspectorPrompt(_ prompt: String)
  func sendContextPrompt(_ prompt: String)
  func sendCropPrompt(_ prompt: String)
}
