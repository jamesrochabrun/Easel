//
//  EaselDesignSystemPreviewScene.swift
//  EaselChat
//

import Foundation

/// A schematic, locally-synthesized preview of a component/example frame: a
/// flat list of positioned primitives (rects, text, image fills, vector paths)
/// in the frame's own coordinate space. Both the native renderer (SwiftUI) and
/// the generated `index.html` (inline SVG) draw from this single description, so
/// no rasterization or rendered Figma image is required.
public struct EaselDesignSystemPreviewScene: Codable, Equatable, Sendable {
  public let width: Double
  public let height: Double
  public let background: String?
  public let layers: [EaselDesignSystemPreviewLayer]

  public init(
    width: Double,
    height: Double,
    background: String?,
    layers: [EaselDesignSystemPreviewLayer]
  ) {
    self.width = width
    self.height = height
    self.background = background
    self.layers = layers
  }
}

public struct EaselDesignSystemPreviewLayer: Codable, Equatable, Identifiable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case rect
    case text
    case image
    case path
  }

  public let id: String
  public let kind: Kind
  public let x: Double
  public let y: Double
  public let width: Double
  public let height: Double
  public let cornerRadius: Double?
  public let fill: String?
  public let stroke: String?
  public let strokeWidth: Double?
  public let opacity: Double?
  public let text: String?
  public let fontSize: Double?
  public let fontWeight: String?
  public let textColor: String?
  public let align: String?
  public let imagePath: String?
  public let path: String?

  public init(
    id: String,
    kind: Kind,
    x: Double,
    y: Double,
    width: Double,
    height: Double,
    cornerRadius: Double? = nil,
    fill: String? = nil,
    stroke: String? = nil,
    strokeWidth: Double? = nil,
    opacity: Double? = nil,
    text: String? = nil,
    fontSize: Double? = nil,
    fontWeight: String? = nil,
    textColor: String? = nil,
    align: String? = nil,
    imagePath: String? = nil,
    path: String? = nil
  ) {
    self.id = id
    self.kind = kind
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.cornerRadius = cornerRadius
    self.fill = fill
    self.stroke = stroke
    self.strokeWidth = strokeWidth
    self.opacity = opacity
    self.text = text
    self.fontSize = fontSize
    self.fontWeight = fontWeight
    self.textColor = textColor
    self.align = align
    self.imagePath = imagePath
    self.path = path
  }
}
