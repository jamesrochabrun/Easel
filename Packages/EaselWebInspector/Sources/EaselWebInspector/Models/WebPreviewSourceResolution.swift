//
//  WebPreviewSourceResolution.swift
//  EaselWebInspector
//
//  Source-mapping models for the web preview inspector rail.
//

import Foundation

// MARK: - WebPreviewSourceResolutionConfidence

public enum WebPreviewSourceResolutionConfidence: Int, Comparable, Sendable {
  case low = 0
  case medium = 1
  case high = 2

  public static func < (lhs: WebPreviewSourceResolutionConfidence, rhs: WebPreviewSourceResolutionConfidence) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public var displayName: String {
    switch self {
    case .low: "Low confidence"
    case .medium: "Medium confidence"
    case .high: "High confidence"
    }
  }
}

// MARK: - WebPreviewEditableCapability

public enum WebPreviewEditableCapability: Hashable, Sendable {
  case content
  case textColor
  case backgroundColor
  case display
  case fontFamily
  case fontSize
  case fontWeight
  case lineHeight
  case letterSpacing
  case textAlign
  case margin
  case opacity
  case padding
  case borderRadius
  case width
  case height
  case top
  case left
  case code
}

// MARK: - WebPreviewStyleProperty

public enum WebPreviewStyleProperty: String, CaseIterable, Hashable, Sendable {
  case textColor = "color"
  case backgroundColor = "background-color"
  case display = "display"
  case fontFamily = "font-family"
  case fontSize = "font-size"
  case fontWeight = "font-weight"
  case lineHeight = "line-height"
  case letterSpacing = "letter-spacing"
  case textAlign = "text-align"
  case margin = "margin"
  case opacity = "opacity"
  case padding = "padding"
  case borderRadius = "border-radius"
  case width = "width"
  case height = "height"
  case top = "top"
  case left = "left"

  public var label: String {
    switch self {
    case .textColor: "Text"
    case .backgroundColor: "Background"
    case .display: "Display"
    case .fontFamily: "Font"
    case .fontSize: "Font Size"
    case .fontWeight: "Font Weight"
    case .lineHeight: "Line Height"
    case .letterSpacing: "Letter Spacing"
    case .textAlign: "Text Align"
    case .margin: "Margin"
    case .opacity: "Opacity"
    case .padding: "Padding"
    case .borderRadius: "Radius"
    case .width: "Width"
    case .height: "Height"
    case .top: "Top"
    case .left: "Left"
    }
  }

  public var capability: WebPreviewEditableCapability {
    switch self {
    case .textColor: .textColor
    case .backgroundColor: .backgroundColor
    case .display: .display
    case .fontFamily: .fontFamily
    case .fontSize: .fontSize
    case .fontWeight: .fontWeight
    case .lineHeight: .lineHeight
    case .letterSpacing: .letterSpacing
    case .textAlign: .textAlign
    case .margin: .margin
    case .opacity: .opacity
    case .padding: .padding
    case .borderRadius: .borderRadius
    case .width: .width
    case .height: .height
    case .top: .top
    case .left: .left
    }
  }

  public var fallbackUnit: String? {
    switch self {
    case .fontSize, .lineHeight, .letterSpacing, .margin, .padding, .borderRadius, .width, .height, .top, .left:
      "px"
    default:
      nil
    }
  }

  public var supportsColorPicking: Bool {
    switch self {
    case .textColor, .backgroundColor:
      true
    default:
      false
    }
  }
}

// MARK: - WebPreviewSourceMatchRange

public struct WebPreviewSourceMatchRange: Equatable, Sendable {
  public let location: Int
  public let length: Int

  public init(location: Int, length: Int) {
    self.location = location
    self.length = length
  }
}

// MARK: - WebPreviewSourceResolution

/// Read-only source mapping for the inspector's Code tab and agent-prompt
/// hints. Resolution never decides where edits are written — style and text
/// edits batch to the session's agent unless a direct mapping is proven.
public struct WebPreviewSourceResolution: Equatable, Sendable {
  public let primaryFilePath: String?
  public let candidateFilePaths: [String]
  public let confidence: WebPreviewSourceResolutionConfidence
  public let matchedRanges: [String: [WebPreviewSourceMatchRange]]
  public let matchedSelector: String?
  public let matchedText: String?

  public init(
    primaryFilePath: String?,
    candidateFilePaths: [String],
    confidence: WebPreviewSourceResolutionConfidence,
    matchedRanges: [String: [WebPreviewSourceMatchRange]],
    matchedSelector: String?,
    matchedText: String?
  ) {
    self.primaryFilePath = primaryFilePath
    self.candidateFilePaths = candidateFilePaths
    self.confidence = confidence
    self.matchedRanges = matchedRanges
    self.matchedSelector = matchedSelector
    self.matchedText = matchedText
  }

  public var isLowConfidence: Bool {
    confidence == .low
  }
}
