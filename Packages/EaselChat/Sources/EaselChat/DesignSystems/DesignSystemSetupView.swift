//
//  DesignSystemSetupView.swift
//  EaselChat
//

import EaselKit
import EaselDesignSystems
import SwiftUI

public struct DesignSystemSetupView: View {
  @Bindable var viewModel: DesignSystemSetupViewModel
  let onCancel: () -> Void
  let onCreated: (EaselDesignSystemLaunch) -> Void

  @State private var activeImporter: DesignSystemResourceImportKind = .assets
  @State private var isImporterPresented = false
  @Environment(\.colorScheme) private var colorScheme

  public init(
    viewModel: DesignSystemSetupViewModel,
    onCancel: @escaping () -> Void,
    onCreated: @escaping (EaselDesignSystemLaunch) -> Void
  ) {
    self.viewModel = viewModel
    self.onCancel = onCancel
    self.onCreated = onCreated
  }

  public var body: some View {
    VStack(spacing: 0) {
      DesignSystemSetupHeader(onCancel: onCancel)

      ScrollView {
        VStack(alignment: .leading, spacing: 26) {
          VStack(spacing: 10) {
            Text("Set up your design system")
              .font(.system(size: 32, weight: .semibold, design: .serif))
              .frame(maxWidth: .infinity)

            Text("Every design system is saved as a spec-compliant DESIGN.md plus a catalog that powers the preview.")
              .font(.title3)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          }
          .padding(.top, 12)

          Picker("How would you like to start?", selection: $viewModel.creationMode) {
            ForEach(DesignSystemSetupViewModel.CreationMode.allCases) { mode in
              Text(mode.title).tag(mode)
            }
          }
          .pickerStyle(.segmented)

          if viewModel.creationMode == .importMarkdown {
            nameField

            VStack(alignment: .leading, spacing: 8) {
              Text("DESIGN.md file")
                .font(.callout.weight(.medium))
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

              DesignSystemFileImportRow(
                title: "Import an existing DESIGN.md",
                buttonTitle: "Browse .md",
                systemImage: "doc.text",
                selectedURLs: viewModel.designMarkdownURL.map { [$0] } ?? [],
                onBrowse: { presentImporter(.designMarkdown) },
                onRemove: { _ in viewModel.removeDesignMarkdown() }
              )
              .padding(20)
              .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
              .overlay {
                RoundedRectangle(cornerRadius: 8)
                  .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
              }

              Text("or paste DESIGN.md")
                .font(.callout.weight(.medium))
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
                .padding(.top, 4)

              TextField(
                "Paste the contents of a DESIGN.md here (YAML front matter + markdown sections)…",
                text: $viewModel.designMarkdownText,
                axis: .vertical
              )
              .textFieldStyle(.plain)
              .font(.system(.callout, design: .monospaced))
              .lineLimit(8...)
              .padding(18)
              .frame(minHeight: 180, alignment: .topLeading)
              .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
              .overlay {
                RoundedRectangle(cornerRadius: 8)
                  .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
              }

              if viewModel.designMarkdownURL != nil && !viewModel.designMarkdownText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Pasted text will be used instead of the selected file.")
                  .font(.footnote)
                  .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              }
            }
          } else {
            if viewModel.creationMode == .generate {
              nameField
            }

            VStack(alignment: .leading, spacing: 8) {
              Text(blurbLabel)
                .font(.callout.weight(.medium))
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

              TextField(
                "e.g. Mission Impastabowl: fast-casual pasta restaurant with in-store touchscreen kiosk, mobile app and website",
                text: $viewModel.blurb,
                axis: .vertical
              )
              .textFieldStyle(.plain)
              .font(.title3)
              .lineLimit(4...)
              .padding(18)
              .frame(minHeight: 116, alignment: .topLeading)
              .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
              .overlay {
                RoundedRectangle(cornerRadius: 8)
                  .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
              }
            }
          }

          if viewModel.creationMode == .describe {
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
              Text("Provide examples of your design system and products")
                .font(.system(size: 24, weight: .semibold, design: .serif))

              Text(" (all optional)")
                .font(.system(size: 24, weight: .regular, design: .serif))
                .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            }

            Text("What works best: code and designs for your design system and your code products.")
              .font(.title3)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          }

          VStack(spacing: 0) {
            DesignSystemGitHubImportRow(viewModel: viewModel)
              .padding(20)

            Divider()

            DesignSystemFileImportRow(
              title: "Link code from your computer",
              buttonTitle: "Browse",
              systemImage: "folder",
              selectedURLs: viewModel.codeSourceURLs,
              onBrowse: { presentImporter(.code) },
              onRemove: viewModel.removeCodeSource
            )
            .padding(20)

            Divider()

            Text("This does not upload the whole codebase; Codex will copy selected files. For large codebases, attach a frontend-focused subfolder.")
              .font(.title3)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(20)

            Divider()

            DesignSystemFileImportRow(
              title: "Upload a .fig file",
              buttonTitle: "Browse .fig",
              systemImage: "doc",
              selectedURLs: viewModel.figFileURLs,
              onBrowse: { presentImporter(.fig) },
              onRemove: viewModel.removeFigFile
            )
            .padding(20)

            Divider()

            DesignSystemFileImportRow(
              title: "Add fonts, logos and assets",
              buttonTitle: "Browse files",
              systemImage: "photo.on.rectangle",
              selectedURLs: viewModel.assetURLs,
              onBrowse: { presentImporter(.assets) },
              onRemove: viewModel.removeAsset
            )
            .padding(20)
          }
          .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
          .overlay {
            RoundedRectangle(cornerRadius: 8)
              .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
          }
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("Any other notes?")
              .font(.callout.weight(.medium))
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

            TextField(
              "e.g. We use a warm, earthy color palette with rounded corners. Our brand voice is playful but professional...",
              text: $viewModel.notes,
              axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.title3)
            .lineLimit(4...)
            .padding(18)
            .frame(minHeight: 116, alignment: .topLeading)
            .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
              RoundedRectangle(cornerRadius: 8)
                .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
            }
          }

          if let errorMessage = viewModel.errorMessage {
            ProjectResourceErrorBanner(message: errorMessage)
          }

          HStack {
            Spacer()

            Button("Cancel", action: onCancel)
              .keyboardShortcut(.cancelAction)

            Button {
              Task {
                if let launch = await viewModel.createDesignSystem() {
                  onCreated(launch)
                }
              }
            } label: {
              Label(viewModel.isCreating ? "Creating" : "Create Design System", systemImage: viewModel.isCreating ? "hourglass" : "sparkles")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.canCreate)
          }
          .padding(.bottom, 28)
        }
        .frame(maxWidth: 860)
        .padding(.horizontal, 32)
      }
    }
    .background(EaselDesignSystem.Palette.canvas(for: colorScheme))
    .fileImporter(
      isPresented: $isImporterPresented,
      allowedContentTypes: activeImporter.allowedContentTypes,
      allowsMultipleSelection: true
    ) { result in
      handleImportResult(result)
    }
  }

  @ViewBuilder
  private var nameField: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Name (optional)")
        .font(.callout.weight(.medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      TextField("e.g. Plus UI", text: $viewModel.nameDraft)
        .textFieldStyle(.plain)
        .font(.title3)
        .padding(18)
        .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
          RoundedRectangle(cornerRadius: 8)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
    }
  }

  private var blurbLabel: String {
    switch viewModel.creationMode {
    case .describe:
      return "Company name and blurb (or name of design system)"
    case .generate:
      return "Describe the brand or product to generate a design system for"
    case .importMarkdown:
      return "Company name and blurb (or name of design system)"
    }
  }

  private func presentImporter(_ importer: DesignSystemResourceImportKind) {
    activeImporter = importer
    isImporterPresented = true
  }

  private func handleImportResult(_ result: Result<[URL], Error>) {
    switch result {
    case let .success(urls):
      switch activeImporter {
      case .code:
        viewModel.addCodeSources(urls)
      case .fig:
        viewModel.addFigFiles(urls)
      case .assets:
        viewModel.addAssets(urls)
      case .designMarkdown:
        viewModel.addDesignMarkdown(urls)
      }
    case let .failure(error):
      viewModel.reportImportFailure(error)
    }
  }
}
