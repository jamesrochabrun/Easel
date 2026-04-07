//
//  WindowMetrics.swift
//  Easel
//

import AppKit

enum WindowMetrics {
  static let capsuleWidth: CGFloat = 600
  static let capsuleHeight: CGFloat = 56
  static let capsuleCornerRadius: CGFloat = 28

  static let canvasWidth: CGFloat = 1200
  static let canvasHeight: CGFloat = 800

  static let animationDuration: TimeInterval = 0.5

  static let timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.9, 0.3, 1.0)
}
