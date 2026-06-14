//
//  WireframeProjectContextPickerView.swift
//  EaselChat
//

import EaselKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct WireframeProjectContextPickerView: View {
  let onStart: (HighFidelityProjectContext) -> Void

  @State private var isScreenshotImporterPresented = false
  @State private var isNotesExpanded = false
  @State private var notes = ""
  @State private var importError: String?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 10) {
        Text("What are we wireframing?")
          .font(.system(size: 34, weight: .regular, design: .serif))
          .foregroundStyle(.primary)
          .multilineTextAlignment(.center)

        Text("Lo-fi moves fast — a screenshot or rough notes is plenty.")
          .font(.title3)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .multilineTextAlignment(.center)
      }
      .padding(.top, 34)
      .padding(.bottom, 32)

      VStack(spacing: 16) {
        contextButton(
          title: "Add a screenshot",
          systemImage: "photo",
          tint: Color(red: 0.34, green: 0.46, blue: 0.27),
          trailingSystemImage: nil,
          action: {
            importError = nil
            isScreenshotImporterPresented = true
          }
        )

        contextButton(
          title: "Paste your notes",
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
      }
      .padding(.horizontal, 58)

      if let importError {
        Text(importError)
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.danger)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 58)
          .padding(.top, 14)
      }

      Spacer(minLength: 28)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .fileImporter(
      isPresented: $isScreenshotImporterPresented,
      allowedContentTypes: [.image],
      allowsMultipleSelection: false
    ) { result in
      handleScreenshotImport(result)
    }
  }

  private var notesPanel: some View {
    VStack(alignment: .trailing, spacing: 12) {
      ZStack(alignment: .topLeading) {
        TextEditor(text: $notes)
          .font(EaselDesignSystem.Typography.interface(size: 14))
          .foregroundStyle(.primary)
          .scrollContentBackground(.hidden)
          .padding(10)
          .frame(minHeight: 128)
          .background(EaselDesignSystem.Palette.surface(for: colorScheme))

        if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text("Paste rough notes, flows, screens, or constraints.")
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

      HStack(spacing: 10) {
        Button("Cancel") {
          withAnimation(.easeInOut(duration: 0.18)) {
            isNotesExpanded = false
          }
        }
        .buttonStyle(.plain)
        .font(.callout.weight(.medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

        Button("Start", action: startWithNotes)
          .buttonStyle(.plain)
          .font(.callout.weight(.semibold))
          .foregroundStyle(startNotesForeground)
          .padding(.horizontal, 14)
          .frame(height: 34)
          .background(startNotesBackground, in: Capsule())
          .disabled(!canStartWithNotes)
      }
    }
  }

  private func contextButton(
    title: String,
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
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(.white)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)

        Text(title)
          .font(.title3.weight(.semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)

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

  private var canStartWithNotes: Bool {
    !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var startNotesForeground: Color {
    canStartWithNotes
      ? EaselDesignSystem.Palette.primaryActionForeground(for: colorScheme)
      : EaselDesignSystem.Palette.tertiaryText(for: colorScheme)
  }

  private var startNotesBackground: Color {
    canStartWithNotes
      ? EaselDesignSystem.Palette.primaryAction(for: colorScheme)
      : EaselDesignSystem.Palette.subtleSurface(for: colorScheme)
  }

  private func handleScreenshotImport(_ result: Result<[URL], Error>) {
    switch result {
    case let .success(urls):
      let imageURLs = Array(urls.prefix(1))
      guard !imageURLs.isEmpty else {
        importError = "No screenshot was selected."
        return
      }
      importError = nil
      onStart(HighFidelityProjectContext(resourceURLs: imageURLs))
    case let .failure(error):
      let nsError = error as NSError
      if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
        return
      }
      importError = error.localizedDescription
    }
  }

  private func startWithNotes() {
    let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedNotes.isEmpty else { return }

    onStart(HighFidelityProjectContext(textResources: [
      ProjectTextResource(
        fileName: "wireframe-notes.md",
        contents: """
        # Wireframe notes

        \(trimmedNotes)
        """
      )
    ]))
  }
}
