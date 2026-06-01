//
//  DesignSystemSetupView.swift
//  EaselChat
//

import EaselKit
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

            Text("Tell us about your company and attach any design resources you have.")
              .font(.title3)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          }
          .padding(.top, 12)

          VStack(alignment: .leading, spacing: 8) {
            Text("Company name and blurb (or name of design system)")
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

            Text("Parsed locally by Codex from this design-system folder.")
              .font(.title3)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .frame(maxWidth: .infinity, alignment: .leading)
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
      }
    case let .failure(error):
      viewModel.reportImportFailure(error)
    }
  }
}
