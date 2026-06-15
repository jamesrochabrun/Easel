//
//  HighFidelityProjectContextPickerView.swift
//  EaselChat
//

import EaselKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct HighFidelityProjectContextPickerView: View {
  let selectedDesignSystemName: String?
  let onDesignSystem: () -> Void
  let onStart: (HighFidelityProjectContext) -> Void

  @State private var screenshotURLs: [URL] = []
  @State private var figmaURLs: [URL] = []
  @State private var codebaseURLs: [URL] = []
  @State private var activeImporter: HighFidelityProjectContextImportKind?
  @State private var isImporterPresented = false
  @State private var isFigmaHelpPresented = false
  @State private var importError: String?
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 12) {
        Text("Start with context")
          .font(.system(size: 34, weight: .regular, design: .serif))
          .foregroundStyle(.primary)
          .multilineTextAlignment(.center)

        Text("Designs grounded in real context turn out better.")
          .font(.title3)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .multilineTextAlignment(.center)
      }
      .padding(.top, 34)
      .padding(.bottom, 26)

      VStack(spacing: 16) {
        contextButton(
          title: "Design system",
          subtitle: selectedDesignSystemName,
          systemImage: "rectangle.3.group",
          tint: Color(red: 0.78, green: 0.36, blue: 0.22),
          action: onDesignSystem
        )

        contextButton(
          title: "Screenshot",
          subtitle: screenshotSummary,
          systemImage: "photo",
          tint: Color(red: 0.34, green: 0.46, blue: 0.27),
          action: {
            presentImporter(.screenshots)
          }
        )

        contextButton(
          title: "Codebase",
          subtitle: codebaseSummary,
          systemImage: "chevron.left.forwardslash.chevron.right",
          tint: Color(red: 0.26, green: 0.51, blue: 0.75),
          action: {
            presentImporter(.codebase)
          }
        )

        figmaButton
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

      Button(startButtonTitle, action: start)
        .buttonStyle(.plain)
        .font(.callout.weight(.medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .padding(.top, 24)
        .padding(.bottom, 28)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .fileImporter(
      isPresented: $isImporterPresented,
      allowedContentTypes: activeImporter?.allowedContentTypes ?? [.item],
      allowsMultipleSelection: activeImporter?.allowsMultipleSelection ?? false
    ) { result in
      handleImportResult(result)
    }
  }

  private var figmaButton: some View {
    HStack(spacing: 0) {
      Button {
        presentImporter(.figma)
      } label: {
        contextButtonLabel(
          title: "Figma",
          subtitle: figmaSummary,
          systemImage: "doc.richtext",
          tint: Color(red: 0.70, green: 0.28, blue: 0.45)
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity)

      Button("How to download a .fig file", systemImage: "questionmark.circle") {
        isFigmaHelpPresented = true
      }
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
      .font(.title3)
      .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .frame(width: 44, height: 44)
      .help("How to download a .fig file")
      .popover(isPresented: $isFigmaHelpPresented) {
        FigmaLocalFileHelpPopover()
          .frame(width: 420)
      }
    }
    .padding(.leading, 18)
    .padding(.trailing, 14)
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

  private func contextButton(
    title: String,
    subtitle: String?,
    systemImage: String,
    tint: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      contextButtonLabel(
        title: title,
        subtitle: subtitle,
        systemImage: systemImage,
        tint: tint
      )
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

  private func contextButtonLabel(
    title: String,
    subtitle: String?,
    systemImage: String,
    tint: Color
  ) -> some View {
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
    }
  }

  private var hasContext: Bool {
    selectedDesignSystemName != nil
      || !screenshotURLs.isEmpty
      || !figmaURLs.isEmpty
      || !codebaseURLs.isEmpty
  }

  private var startButtonTitle: String {
    hasContext ? "Start" : "Start without context"
  }

  private var screenshotSummary: String? {
    selectionSummary(for: screenshotURLs, plural: "images")
  }

  private var figmaSummary: String? {
    selectionSummary(for: figmaURLs, plural: ".fig files")
  }

  private var codebaseSummary: String? {
    guard let codebaseURL = codebaseURLs.first else {
      return "Read-only reference. This session will inspect it only."
    }

    return "\(codebaseURL.lastPathComponent) selected. Easel will not modify it."
  }

  private func selectionSummary(for urls: [URL], plural: String) -> String? {
    switch urls.count {
    case 0:
      return nil
    case 1:
      return "\(urls[0].lastPathComponent) selected."
    default:
      return "\(urls.count) \(plural) selected."
    }
  }

  private func presentImporter(_ kind: HighFidelityProjectContextImportKind) {
    activeImporter = kind
    importError = nil
    isImporterPresented = true
  }

  private func handleImportResult(_ result: Result<[URL], Error>) {
    guard let activeImporter else { return }
    self.activeImporter = nil

    switch result {
    case let .success(urls):
      switch activeImporter {
      case .screenshots:
        screenshotURLs = Self.appendingUnique(urls, to: screenshotURLs)
      case .figma:
        let figURLs = urls.filter { $0.pathExtension.lowercased() == "fig" }
        figmaURLs = Self.appendingUnique(figURLs, to: figmaURLs)
      case .codebase:
        codebaseURLs = Array(urls.prefix(1))
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

  private func start() {
    onStart(HighFidelityProjectContext(
      resourceURLs: screenshotURLs + figmaURLs,
      codebaseURLs: codebaseURLs
    ))
  }

  private static func appendingUnique(_ urls: [URL], to existingURLs: [URL]) -> [URL] {
    var result = existingURLs
    for url in urls where !result.contains(url) {
      result.append(url)
    }
    return result
  }
}
