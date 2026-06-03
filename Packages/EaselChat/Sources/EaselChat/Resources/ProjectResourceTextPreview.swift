//
//  ProjectResourceTextPreview.swift
//  EaselChat
//

import SwiftUI

struct ProjectResourceTextPreview: View {
  let item: ProjectResourcePanelItem
  let text: String
  let onSave: (String) async throws -> Void

  @State private var draftText: String
  @State private var savedText: String
  @State private var displayMode: ProjectResourceEditorDisplayMode
  @State private var documentID = UUID()
  @State private var isSaving = false
  @State private var saveError: String?

  init(
    item: ProjectResourcePanelItem,
    text: String,
    onSave: @escaping (String) async throws -> Void
  ) {
    self.item = item
    self.text = text
    self.onSave = onSave
    _draftText = State(initialValue: text)
    _savedText = State(initialValue: text)
    _displayMode = State(initialValue: .displayMode(for: text))
  }

  var body: some View {
    VStack(spacing: 0) {
      editorToolbar

      Rectangle()
        .fill(.quaternary)
        .frame(height: 1)

      ProjectResourceSourceEditorView(
        text: $draftText,
        fileName: item.fileName,
        documentID: documentID,
        displayMode: displayMode
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.background)
    .onChange(of: item.id) { _, _ in
      resetEditor(to: text)
    }
    .onChange(of: text) { _, newText in
      guard !hasUnsavedChanges || newText == draftText else { return }
      resetEditor(to: newText)
    }
  }

  private var hasUnsavedChanges: Bool {
    draftText != savedText
  }

  private var editorToolbar: some View {
    HStack(spacing: 8) {
      if let badgeLabel = displayMode.badgeLabel {
        Text(badgeLabel)
          .font(.caption2.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.tertiary, in: Capsule())
      }

      if hasUnsavedChanges {
        Text("Modified")
          .font(.caption2.weight(.medium))
          .foregroundStyle(.orange)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.orange.opacity(0.14), in: Capsule())
      }

      Spacer(minLength: 8)

      if let saveError {
        Text(saveError)
          .font(.caption2)
          .foregroundStyle(.red)
          .lineLimit(1)
      }

      Button("Save", systemImage: "square.and.arrow.down") {
        save()
      }
      .controlSize(.small)
      .keyboardShortcut("s", modifiers: .command)
      .disabled(!hasUnsavedChanges || isSaving)
    }
    .padding(.horizontal, 12)
    .frame(height: 36)
    .background(.bar)
  }

  private func resetEditor(to text: String) {
    draftText = text
    savedText = text
    saveError = nil
    displayMode = .displayMode(for: text)
    documentID = UUID()
  }

  private func save() {
    guard !isSaving else { return }
    isSaving = true
    saveError = nil
    let textToSave = draftText

    Task {
      do {
        try await onSave(textToSave)
        await MainActor.run {
          savedText = textToSave
          displayMode = .displayMode(for: textToSave)
          isSaving = false
        }
      } catch {
        await MainActor.run {
          saveError = error.localizedDescription
          isSaving = false
        }
      }
    }
  }
}
