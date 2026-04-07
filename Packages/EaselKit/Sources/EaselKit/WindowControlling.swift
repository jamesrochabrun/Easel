//
//  WindowControlling.swift
//  EaselKit
//

@MainActor
public protocol WindowControlling: AnyObject {
  func showCapsule()
  func animateToCanvas()
  func animateToCapsule()
}
