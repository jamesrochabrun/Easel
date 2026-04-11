//
//  WindowControlling.swift
//  EaselKit
//

@MainActor
public protocol WindowControlling: AnyObject {
  func showCapsule()
  func hideCapsule()
  func animateToCanvas()
  func animateToCapsule()
}
