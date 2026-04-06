//
//  PanelControlling.swift
//  EaselKit
//

@MainActor
public protocol PanelControlling: AnyObject {
  func showCapsule()
  func animateToCanvas()
  func animateToCapsule()
}
