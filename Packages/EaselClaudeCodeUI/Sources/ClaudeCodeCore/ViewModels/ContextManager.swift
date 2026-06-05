//
//  ContextManager.swift
//  ClaudeCodeUI
//
//  Created on 12/27/24.
//

import Foundation
import SwiftUI

/// Manages the code context that will be included in chat messages
@Observable
@MainActor
public final class ContextManager {
  
  // MARK: - Observable Properties
  
  /// The current context model
  private(set) var context: ContextModel = ContextModel()
  
  // MARK: - Initialization
  
  init() {}
  
  // MARK: - Public Methods
  
  /// Manually adds a file to the context
  func addFile(_ file: FileInfo) {
    context.addFile(file)
  }
  
  /// Manually adds a selection to the context
  func addSelection(_ selection: TextSelection) {
    context.addSelection(selection)
  }
  
  /// Removes a specific selection by ID
  func removeSelection(id: UUID) {
    context.removeSelection(id: id)
  }
  
  /// Removes a specific file by ID
  func removeFile(id: UUID) {
    context.removeFile(id: id)
  }
  
  /// Clears all context
  func clearAll() {
    context.clear()
  }
  
  /// Sets additional notes for the context
  func setNotes(_ notes: String?) {
    context.notes = notes
  }
  
  /// Gets the formatted context for inclusion in a prompt
  func getFormattedContext() -> String {
    context.buildPromptContext()
  }
  
  /// Checks if there's any context available
  var hasContext: Bool {
    !context.isEmpty()
  }
  
  /// Gets the context summary for UI display
  var contextSummary: String {
    context.summary
  }
  
}
