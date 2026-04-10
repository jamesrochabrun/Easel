//
//  WebPreviewContextQueue.swift
//  EaselWebInspector
//

import Canvas
import CoreGraphics
import Foundation

/// A web-preview selection queued for the next submit.
public struct WebPreviewQueuedUpdate: Identifiable, Equatable, Sendable {
  public enum Selection: Equatable, Sendable {
    case element(ElementInspectorData)
    case crop(WebPreviewQueuedCropSelection)
  }

  public let id: UUID
  public let selection: Selection
  public let instruction: String?

  public init(
    id: UUID = UUID(),
    selection: Selection,
    instruction: String? = nil
  ) {
    self.id = id
    self.selection = selection
    self.instruction = Self.normalizedInstruction(instruction)
  }

  public init(
    element: ElementInspectorData,
    instruction: String? = nil
  ) {
    self.init(id: element.id, selection: .element(element), instruction: instruction)
  }

  public init(
    cropRect: CGRect,
    elements: [ElementInspectorData],
    instruction: String,
    screenshotPath: String?
  ) {
    self.init(
      selection: .crop(WebPreviewQueuedCropSelection(
        cropRect: cropRect,
        elements: elements,
        screenshotPath: screenshotPath
      )),
      instruction: instruction
    )
  }

  public var kindLabel: String {
    switch selection {
    case .element: return instruction == nil ? "Context" : "Element"
    case .crop: return "Region"
    }
  }

  public var iconName: String {
    switch selection {
    case .element: return instruction == nil ? "square.and.arrow.up" : "cursorarrow.rays"
    case .crop: return "crop"
    }
  }

  public var summary: String {
    switch selection {
    case .element(let element):
      let tag = element.tagName.isEmpty ? "element" : element.tagName.lowercased()
      guard !element.cssSelector.isEmpty else { return tag }
      return "\(tag) \(element.cssSelector)"
    case .crop(let crop):
      return "Region \(Int(crop.cropRect.width)) x \(Int(crop.cropRect.height)) px"
    }
  }

  public var detail: String {
    if let instruction {
      return instruction
    }

    switch selection {
    case .element(let element):
      if !element.outerHTML.isEmpty {
        return element.outerHTML
      }
      if !element.textContent.isEmpty {
        return "\"\(element.textContent)\""
      }
      return element.tagName.lowercased()
    case .crop(let crop):
      return "\(crop.elements.count) captured element\(crop.elements.count == 1 ? "" : "s")"
    }
  }

  public var prompt: String {
    switch selection {
    case .element(let element):
      if let instruction {
        return ElementInspectorPromptBuilder.buildPrompt(
          element: element,
          instruction: instruction
        )
      }
      return ElementInspectorPromptBuilder.buildContextPrompt(element: element)

    case .crop(let crop):
      return ElementInspectorPromptBuilder.buildCropPrompt(
        cropRect: crop.cropRect,
        elements: crop.elements,
        instruction: instruction ?? "Use this selected region as additional context.",
        screenshotPath: nil
      )
    }
  }

  private static func normalizedInstruction(_ instruction: String?) -> String? {
    guard let instruction else { return nil }
    let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

public struct WebPreviewQueuedCropSelection: Equatable, Sendable {
  public let cropRect: CGRect
  public let elements: [ElementInspectorData]
  public let screenshotPath: String?

  public init(cropRect: CGRect, elements: [ElementInspectorData], screenshotPath: String?) {
    self.cropRect = cropRect
    self.elements = elements
    self.screenshotPath = screenshotPath
  }
}

/// Holds the set of web-preview updates queued for the next submit.
public struct WebPreviewContextQueue: Equatable, Sendable {
  public private(set) var items: [WebPreviewQueuedUpdate] = []

  public init() {}

  public var isEmpty: Bool {
    items.isEmpty
  }

  public var count: Int {
    items.count
  }

  public mutating func append(_ element: ElementInspectorData) {
    append(element, instruction: nil)
  }

  public mutating func append(_ element: ElementInspectorData, instruction: String?) {
    items.append(WebPreviewQueuedUpdate(element: element, instruction: instruction))
  }

  public mutating func appendCrop(
    cropRect: CGRect,
    elements: [ElementInspectorData],
    instruction: String,
    screenshotPath: String?
  ) {
    items.append(WebPreviewQueuedUpdate(
      cropRect: cropRect,
      elements: elements,
      instruction: instruction,
      screenshotPath: screenshotPath
    ))
  }

  public mutating func append(contentsOf updates: [WebPreviewQueuedUpdate]) {
    items.append(contentsOf: updates)
  }

  public mutating func remove(id: UUID) {
    items.removeAll { $0.id == id }
  }

  public mutating func clear() {
    items.removeAll()
  }

  public func composedContextPrompt() -> String? {
    guard !items.isEmpty else { return nil }
    if items.count == 1, let item = items.first {
      return item.prompt
    }

    var lines = [
      "Queued web preview updates:",
      "",
      "Please apply these updates together.",
      "",
    ]

    for (index, item) in items.enumerated() {
      lines.append("## Update \(index + 1): \(item.kindLabel)")
      lines.append("")
      lines.append(item.prompt)
      if index < items.count - 1 {
        lines.append("")
      }
    }

    return lines.joined(separator: "\n")
  }

  /// Returns screenshot file paths from crop items, in queue order.
  public func screenshotPaths() -> [String] {
    items.compactMap { item in
      guard case .crop(let crop) = item.selection else { return nil }
      return crop.screenshotPath
    }
  }
}
