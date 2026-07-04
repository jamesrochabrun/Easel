//
//  WebPreviewPendingDesignEdits.swift
//  EaselWebInspector
//
//  Pending design edits captured in Edit Mode. Style and text changes are
//  batched per element and applied to source by the session's agent instead
//  of direct file writes.
//

import Canvas
import Foundation

/// A single pending CSS property change, deduped by property with last-wins values.
public struct WebPreviewPendingStyleChange: Equatable, Sendable {
  public let property: String
  /// The first-seen value before any pending edit, when one was known.
  public let oldValue: String?
  public var newValue: String

  public init(property: String, oldValue: String?, newValue: String) {
    self.property = property
    self.oldValue = oldValue
    self.newValue = newValue
  }
}

/// A pending text-content replacement for the selected element.
public struct WebPreviewPendingTextChange: Equatable, Sendable {
  /// The text before any pending edit, when one was known.
  public let oldText: String?
  public var newText: String

  public init(oldText: String?, newText: String) {
    self.oldText = oldText
    self.newText = newText
  }
}

/// All pending design edits for one selected element.
public struct WebPreviewPendingDesignEditBatch: Equatable, Sendable {
  public let element: ElementInspectorData
  public private(set) var styleChanges: [WebPreviewPendingStyleChange] = []
  public private(set) var textChange: WebPreviewPendingTextChange?

  public init(element: ElementInspectorData) {
    self.element = element
  }

  public var isEmpty: Bool {
    styleChanges.isEmpty && textChange == nil
  }

  public var changeCount: Int {
    styleChanges.count + (textChange == nil ? 0 : 1)
  }

  public mutating func recordStyleChange(property: String, oldValue: String?, newValue: String) {
    let normalizedOld = oldValue?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

    if let index = styleChanges.firstIndex(where: { $0.property == property }) {
      // Reverting to the first-seen value cancels the pending change.
      if let originalValue = styleChanges[index].oldValue, originalValue == newValue {
        styleChanges.remove(at: index)
        return
      }
      styleChanges[index].newValue = newValue
      return
    }

    if let normalizedOld, normalizedOld == newValue {
      return
    }

    styleChanges.append(WebPreviewPendingStyleChange(
      property: property,
      oldValue: normalizedOld,
      newValue: newValue
    ))
  }

  public mutating func removeStyleChange(property: String) {
    styleChanges.removeAll { $0.property == property }
  }

  public mutating func recordTextChange(oldText: String?, newText: String) {
    if let existing = textChange {
      if let originalText = existing.oldText, originalText == newText {
        textChange = nil
        return
      }
      textChange = WebPreviewPendingTextChange(oldText: existing.oldText, newText: newText)
      return
    }

    if let oldText, oldText == newText {
      return
    }

    textChange = WebPreviewPendingTextChange(oldText: oldText, newText: newText)
  }
}

/// The element-anchored agent instruction produced when a pending batch is
/// handed off for sending (Apply button, element switch, or panel close).
public struct WebPreviewPendingDesignEditHandoff: Equatable, Sendable {
  public let element: ElementInspectorData
  public let instruction: String

  public init(element: ElementInspectorData, instruction: String) {
    self.element = element
    self.instruction = instruction
  }
}
