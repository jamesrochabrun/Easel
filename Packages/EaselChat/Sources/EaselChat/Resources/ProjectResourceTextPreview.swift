//
//  ProjectResourceTextPreview.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceTextPreview: View {
  let item: ProjectResourcePanelItem
  let text: String
  let isSaving: Bool
  let onSave: (String) -> Void

  init(
    item: ProjectResourcePanelItem,
    text: String,
    isSaving: Bool,
    onSave: @escaping (String) -> Void
  ) {
    self.item = item
    self.text = text
    self.isSaving = isSaving
    self.onSave = onSave
    self._editorText = State(initialValue: text)
    self._savedText = State(initialValue: text)
    self._displayMode = State(initialValue: .displayMode(for: text))
  }

  @State private var editorText: String
  @State private var savedText: String
  @State private var displayMode: EditorDisplayMode
  @State private var editorDocumentID = UUID()
  @State private var hasUnsavedChanges = false

  var body: some View {
    codePreview
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(editorBackground)
    .onChange(of: item.id) { _, _ in
      resetEditor(with: text)
    }
    .onChange(of: text) { _, newText in
      resetEditor(with: newText)
    }
  }

  private var codePreview: some View {
    VStack(spacing: 0) {
      editorHeader

      SourceCodeEditorView(
        text: $editorText,
        fileName: item.fileName,
        documentID: editorDocumentID,
        displayMode: displayMode,
        isEditable: true,
        onTextChange: editorTextChanged,
        onIdleTextSnapshot: editorIdleSnapshot
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var editorHeader: some View {
    HStack(spacing: 8) {
      Text(languageDisplayName.uppercased())
        .font(.system(size: 11, weight: .medium, design: .monospaced))
        .foregroundStyle(.secondary)

      if let badgeLabel = displayMode.badgeLabel {
        Text(badgeLabel)
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 5)
          .padding(.vertical, 1)
          .background(
            Capsule()
              .fill(Color.secondary.opacity(0.14))
          )
      }

      if hasUnsavedChanges {
        Text("Modified")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.orange)
          .padding(.horizontal, 5)
          .padding(.vertical, 1)
          .background(
            Capsule()
              .fill(Color.orange.opacity(0.16))
          )
      }

      Spacer(minLength: 8)

      if hasUnsavedChanges {
        Button("Save") {
          onSave(editorText)
        }
        .keyboardShortcut("s", modifiers: .command)
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(isSaving)
      }
    }
    .frame(height: 32)
    .padding(.horizontal, 14)
    .background(editorHeaderBackground)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.white.opacity(0.08))
        .frame(height: 1)
    }
  }

  private var languageDisplayName: String {
    SourceEditorLanguageResolver.languageIdentifier(
      forFileName: item.fileName,
      content: editorText,
      displayMode: displayMode
    )
  }

  private var editorBackground: Color {
    Color(red: 0.07, green: 0.09, blue: 0.11)
  }

  private var editorHeaderBackground: Color {
    Color(red: 0.09, green: 0.11, blue: 0.13)
  }

  private func editorTextChanged(_ updatedText: String) {
    if !hasUnsavedChanges {
      hasUnsavedChanges = updatedText != savedText
    }
  }

  private func editorIdleSnapshot(_ idleText: String) {
    hasUnsavedChanges = idleText != savedText
  }

  private func resetEditor(with text: String) {
    editorText = text
    savedText = text
    displayMode = .displayMode(for: text)
    editorDocumentID = UUID()
    hasUnsavedChanges = false
  }
}
