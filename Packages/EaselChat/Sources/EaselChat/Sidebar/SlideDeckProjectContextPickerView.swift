//
//  SlideDeckProjectContextPickerView.swift
//  EaselChat
//

import EaselKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct SlideDeckProjectContextPickerView: View {
  let onStart: (HighFidelityProjectContext) -> Void

  @State private var documentURLs: [URL] = []
  @State private var deckURLs: [URL] = []
  @State private var notes = ""
  @State private var activeImporter: SlideDeckProjectContextImportKind?
  @State private var isImporterPresented = false
  @State private var isNotesExpanded = false
  @State private var importError: String?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 0) {
          VStack(spacing: 12) {
            Text("What's the presentation about?")
              .font(.system(size: 34, weight: .regular, design: .serif))
              .foregroundStyle(.primary)
              .multilineTextAlignment(.center)

            Text("Upload a doc, share your notes, or an existing presentation\nto start from.")
              .font(.title3)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(.top, 44)
          .padding(.bottom, 40)

          VStack(spacing: 16) {
            contextButton(
              title: "Upload a doc",
              subtitle: documentSummary,
              systemImage: "doc.text",
              tint: Color(red: 0.34, green: 0.46, blue: 0.27),
              trailingSystemImage: nil,
              action: {
                presentImporter(.document)
              }
            )

            contextButton(
              title: "Paste your notes",
              subtitle: notesSummary,
              systemImage: "pencil",
              tint: Color(red: 0.26, green: 0.51, blue: 0.75),
              trailingSystemImage: isNotesExpanded ? "chevron.up" : "chevron.down",
              action: {
                withAnimation(.easeInOut(duration: 0.18)) {
                  isNotesExpanded.toggle()
                }
              }
            )

            if isNotesExpanded {
              notesPanel
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            contextButton(
              title: "Existing deck",
              subtitle: deckSummary,
              systemImage: "rectangle.on.rectangle",
              tint: Color(red: 0.81, green: 0.32, blue: 0.20),
              trailingSystemImage: nil,
              action: {
                presentImporter(.existingDeck)
              }
            )
          }
          .frame(maxWidth: 400)
          .padding(.horizontal, 58)

          if let importError {
            Text(importError)
              .font(.caption)
              .foregroundStyle(EaselDesignSystem.Palette.danger)
              .fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: 400, alignment: .leading)
              .padding(.horizontal, 58)
              .padding(.top, 14)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 22)
      }

      Button(startButtonTitle, action: start)
        .buttonStyle(.plain)
        .font(.callout.weight(.medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .padding(.top, 10)
        .padding(.bottom, 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .fileImporter(
      isPresented: $isImporterPresented,
      allowedContentTypes: activeImporter?.allowedContentTypes ?? [.item],
      allowsMultipleSelection: false
    ) { result in
      handleImportResult(result)
    }
  }

  private var notesPanel: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: $notes)
        .font(EaselDesignSystem.Typography.interface(size: 14))
        .foregroundStyle(.primary)
        .scrollContentBackground(.hidden)
        .padding(10)
        .frame(minHeight: 128)
        .background(EaselDesignSystem.Palette.surface(for: colorScheme))

      if trimmedNotes.isEmpty {
        Text("Paste the storyline, audience, sections, constraints, or source notes.")
          .font(EaselDesignSystem.Typography.interface(size: 14))
          .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
          .padding(.horizontal, 16)
          .padding(.vertical, 18)
          .allowsHitTesting(false)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
  }

  private var hasContext: Bool {
    !documentURLs.isEmpty || !deckURLs.isEmpty || !trimmedNotes.isEmpty
  }

  private var startButtonTitle: String {
    hasContext ? "Start" : "Start without context"
  }

  private var documentSummary: String? {
    fileSummary(for: documentURLs)
  }

  private var deckSummary: String? {
    fileSummary(for: deckURLs)
  }

  private var notesSummary: String? {
    guard !trimmedNotes.isEmpty else { return nil }
    return "Notes added."
  }

  private var trimmedNotes: String {
    notes.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var textResources: [ProjectTextResource] {
    guard !trimmedNotes.isEmpty else { return [] }

    return [
      ProjectTextResource(
        fileName: "slides-notes.md",
        contents: """
        # Presentation notes

        \(trimmedNotes)
        """
      )
    ]
  }

  private func contextButton(
    title: String,
    subtitle: String?,
    systemImage: String,
    tint: Color,
    trailingSystemImage: String?,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 20) {
        ZStack {
          Circle()
            .fill(tint)
          Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)

          if let subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
          }
        }

        Spacer(minLength: 0)

        if let trailingSystemImage {
          Image(systemName: trailingSystemImage)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .accessibilityHidden(true)
        }
      }
      .padding(.horizontal, 18)
      .frame(minHeight: 70)
      .frame(maxWidth: .infinity)
      .background(
        EaselDesignSystem.Palette.surface(for: colorScheme),
        in: Capsule()
      )
      .overlay {
        Capsule()
          .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
      }
      .shadow(color: .black.opacity(colorScheme == .dark ? 0.18 : 0.07), radius: 4, y: 2)
    }
    .buttonStyle(.plain)
  }

  private func presentImporter(_ kind: SlideDeckProjectContextImportKind) {
    activeImporter = kind
    importError = nil
    isImporterPresented = true
  }

  private func handleImportResult(_ result: Result<[URL], Error>) {
    guard let activeImporter else { return }
    self.activeImporter = nil

    switch result {
    case let .success(urls):
      let selectedURLs = Array(urls.prefix(1))
      guard !selectedURLs.isEmpty else {
        importError = activeImporter.emptySelectionMessage
        return
      }

      switch activeImporter {
      case .document:
        documentURLs = selectedURLs
      case .existingDeck:
        deckURLs = selectedURLs
      }
      importError = nil
    case let .failure(error):
      let nsError = error as NSError
      if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
        return
      }
      importError = error.localizedDescription
    }
  }

  private func fileSummary(for urls: [URL]) -> String? {
    guard let url = urls.first else { return nil }
    return "\(url.lastPathComponent) selected."
  }

  private func start() {
    onStart(HighFidelityProjectContext(
      resourceURLs: documentURLs + deckURLs,
      textResources: textResources
    ))
  }
}
