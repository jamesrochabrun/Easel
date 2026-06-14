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
  @State private var screenshotURLs: [URL] = []
  @State private var notes = ""
  @State private var importError: String?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
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
              subtitle: screenshotSummary,
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
        }
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
      isPresented: $isScreenshotImporterPresented,
      allowedContentTypes: [.image],
      allowsMultipleSelection: false
    ) { result in
      handleScreenshotImport(result)
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
  }

  private var hasContext: Bool {
    !screenshotURLs.isEmpty || !trimmedNotes.isEmpty
  }

  private var startButtonTitle: String {
    hasContext ? "Start" : "Start without context"
  }

  private var screenshotSummary: String? {
    guard let screenshotURL = screenshotURLs.first else { return nil }
    return "\(screenshotURL.lastPathComponent) selected."
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
        fileName: "wireframe-notes.md",
        contents: """
        # Wireframe notes

        \(trimmedNotes)
        """
      )
    ]
  }

  private func start() {
    onStart(HighFidelityProjectContext(
      resourceURLs: screenshotURLs,
      textResources: textResources
    ))
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
            .font(.system(size: 19, weight: .semibold))
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

  private func handleScreenshotImport(_ result: Result<[URL], Error>) {
    switch result {
    case let .success(urls):
      let imageURLs = Array(urls.prefix(1))
      guard !imageURLs.isEmpty else {
        importError = "No screenshot was selected."
        return
      }
      importError = nil
      screenshotURLs = imageURLs
    case let .failure(error):
      let nsError = error as NSError
      if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
        return
      }
      importError = error.localizedDescription
    }
  }
}
