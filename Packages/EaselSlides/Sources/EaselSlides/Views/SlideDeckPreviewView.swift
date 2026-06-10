//
//  SlideDeckPreviewView.swift
//  EaselSlides
//

import AppKit
import EaselKit
import SwiftUI

public struct SlideDeckPreviewView: View {
  let previewURLProvider: PreviewURLProviding
  let projectPath: String?

  @State private var selectedIndex = 0
  @State private var metadata = SlideDeckMetadata.empty
  @State private var thumbnailsByIndex: [Int: NSImage] = [:]
  @State private var reloadToken = UUID()
  @State private var isLoading = false
  @State private var isPresentingInTab = false
  @State private var presentationHandler: any SlideDeckPresentationHandling
  @State private var errorMessage: String?
  @Environment(\.colorScheme) private var colorScheme

  public init(
    previewURLProvider: PreviewURLProviding,
    projectPath: String?
  ) {
    self.init(
      previewURLProvider: previewURLProvider,
      projectPath: projectPath,
      presentationHandler: DefaultSlideDeckPresentationHandler()
    )
  }

  init(
    previewURLProvider: PreviewURLProviding,
    projectPath: String?,
    presentationHandler: any SlideDeckPresentationHandling
  ) {
    self.previewURLProvider = previewURLProvider
    self.projectPath = projectPath
    _presentationHandler = State(initialValue: presentationHandler)
  }

  public var body: some View {
    Group {
      if isPresentingInTab, let url = previewURLProvider.previewURL {
        SlideDeckPresentationView(
          url: url,
          initialSelectedIndex: selectedIndex,
          reloadToken: reloadToken,
          onSelectedIndexChange: { selectedIndex = $0 },
          onDismiss: { isPresentingInTab = false }
        )
      } else {
        previewContent
      }
    }
    .background(Color.black)
    .task(id: autoReloadTaskID) {
      await observeProjectFileChangesForAutoReload()
    }
  }

  private var previewContent: some View {
    VStack(spacing: 0) {
      header

      Divider()

      if let url = previewURLProvider.previewURL {
        slideDeckContent(url: url)
      } else {
        placeholderView
      }
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      Label("Slides", systemImage: "rectangle.on.rectangle")
        .font(.caption.weight(.medium))
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))

      if !metadata.slides.isEmpty {
        Text("\(selectedIndex + 1) of \(metadata.slides.count)")
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
      }

      Spacer()

      presentMenu
      reloadButton
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(minHeight: 40)
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
  }

  private var reloadButton: some View {
    SlideDeckReloadButton(
      isEnabled: previewURLProvider.previewURL != nil,
      action: reloadPreview
    )
    .frame(width: 92, height: 26)
    .help("Refresh slides")
  }

  private var presentMenu: some View {
    SlideDeckPresentMenuButton(
      isEnabled: previewURLProvider.previewURL != nil
    ) { option in
      presentSlides(using: option)
    }
    .frame(width: 104, height: 26)
    .help("Present slides")
  }

  private func slideDeckContent(url: URL) -> some View {
    HStack(spacing: 0) {
      thumbnailRail

      Rectangle()
        .fill(Color.white.opacity(0.08))
        .frame(width: 1)

      mainPreview(url: url)
    }
    .overlay(alignment: .topLeading) {
      if !metadata.slides.isEmpty {
        SlideDeckThumbnailRenderer(
          url: url,
          cacheKey: thumbnailCacheKey(for: url),
          metadata: metadata,
          selectedIndex: selectedIndex,
          onThumbnailRendered: { cacheKey, slideIndex, thumbnail in
            handleThumbnailRendered(cacheKey, slideIndex: slideIndex, thumbnail: thumbnail)
          }
        )
        .frame(width: SlideDeckRenderMetrics.renderSize.width, height: SlideDeckRenderMetrics.renderSize.height)
        .opacity(0.001)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
    }
  }

  private var thumbnailRail: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 12) {
        if metadata.slides.isEmpty {
          VStack(spacing: 10) {
            ProgressView()
              .controlSize(.small)
            Text("Reading slides")
              .font(.caption)
              .foregroundStyle(.white.opacity(0.62))
          }
          .frame(maxWidth: .infinity)
          .padding(.top, 28)
        } else {
          ForEach(metadata.slides) { slide in
            SlideDeckThumbnailButton(
              slide: slide,
              thumbnail: thumbnailsByIndex[slide.index],
              isSelected: slide.index == selectedIndex,
              action: {
                selectedIndex = slide.index
              }
            )
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 16)
    }
    .frame(width: 150)
    .background(Color(red: 0.06, green: 0.06, blue: 0.06))
  }

  private func mainPreview(url: URL) -> some View {
    GeometryReader { proxy in
      let stageSize = stageSize(in: proxy.size)
      let scale = stageSize.width / SlideDeckRenderMetrics.renderSize.width

      ZStack {
        Color.black

        ZStack {
          SlideDeckWebView(
            url: url,
            selectedIndex: selectedIndex,
            reloadToken: reloadToken,
            fastForwardMotion: true,
            onMetadataChange: handleMetadataChange,
            onLoadingChange: handleLoadingChange,
            onError: handleError
          )
          .frame(
            width: SlideDeckRenderMetrics.renderSize.width,
            height: SlideDeckRenderMetrics.renderSize.height
          )
          .background(Color.white)
          .clipped()
          .scaleEffect(scale, anchor: .center)
        }
        .frame(width: stageSize.width, height: stageSize.height)
        .clipped()
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
        .overlay {
          Rectangle()
            .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }

        if isLoading {
          ProgressView()
            .controlSize(.large)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }

        if let errorMessage {
          VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
              .font(.title3)
            Text(errorMessage)
              .font(.caption)
              .multilineTextAlignment(.center)
              .lineLimit(3)
          }
          .foregroundStyle(.white.opacity(0.86))
          .padding(14)
          .frame(maxWidth: 320)
          .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }

  private var placeholderView: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "rectangle.on.rectangle")
        .font(.system(size: 36, weight: .thin))
        .foregroundStyle(.white.opacity(0.36))

      Text("Slides")
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(.white.opacity(0.72))

      Text("Slide preview will appear here")
        .font(.system(size: 13))
        .foregroundStyle(.white.opacity(0.46))

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
  }

  private var autoReloadTaskID: String {
    [
      projectPath ?? "",
      previewURLProvider.previewURL?.absoluteString ?? "",
    ].joined(separator: "|")
  }

  private func thumbnailCacheKey(for url: URL) -> SlideDeckThumbnailCacheKey {
    SlideDeckThumbnailCacheKey(
      url: url,
      reloadToken: reloadToken,
      slideCount: metadata.slides.count
    )
  }

  private func stageSize(in containerSize: CGSize) -> CGSize {
    let horizontalPadding: CGFloat = 80
    let verticalPadding: CGFloat = 80
    let availableWidth = max(containerSize.width - horizontalPadding, 1)
    let availableHeight = max(containerSize.height - verticalPadding, 1)
    let width = min(availableWidth, availableHeight * SlideDeckRenderMetrics.aspectRatio)
    let height = width / SlideDeckRenderMetrics.aspectRatio
    return CGSize(width: width, height: height)
  }

  @MainActor
  private func handleLoadingChange(_ nextIsLoading: Bool) {
    Task { @MainActor in
      isLoading = nextIsLoading
    }
  }

  @MainActor
  private func handleError(_ message: String) {
    Task { @MainActor in
      errorMessage = message
    }
  }

  @MainActor
  private func handleMetadataChange(_ nextMetadata: SlideDeckMetadata) {
    if metadata != nextMetadata {
      thumbnailsByIndex = [:]
    }

    metadata = nextMetadata

    guard !nextMetadata.slides.isEmpty else {
      selectedIndex = 0
      return
    }

    if !nextMetadata.slides.contains(where: { $0.index == selectedIndex }) {
      selectedIndex = nextMetadata.slides[0].index
    }
  }

  @MainActor
  private func handleThumbnailRendered(
    _ cacheKey: SlideDeckThumbnailCacheKey,
    slideIndex: Int,
    thumbnail: NSImage
  ) {
    guard let url = previewURLProvider.previewURL,
          cacheKey == thumbnailCacheKey(for: url) else {
      return
    }

    thumbnailsByIndex[slideIndex] = thumbnail
  }

  @MainActor
  private func reloadPreview() {
    reloadToken = UUID()
    thumbnailsByIndex = [:]
    errorMessage = nil
  }

  @MainActor
  private func presentSlides(using option: SlideDeckPresentationOption) {
    guard let url = previewURLProvider.previewURL else { return }

    switch option {
    case .inThisTab:
      errorMessage = nil
      isPresentingInTab = true
    case .fullscreen:
      presentationHandler.presentFullscreen(
        url: url,
        selectedIndex: selectedIndex,
        reloadToken: reloadToken
      )
    case .newTab:
      presentationHandler.presentInNewTab(
        url: url,
        selectedIndex: selectedIndex
      )
    }
  }

  private func observeProjectFileChangesForAutoReload() async {
    guard let projectPath, !projectPath.isEmpty,
          previewURLProvider.previewURL != nil else {
      return
    }

    let observer = SlideDeckProjectFileChangeObserver(projectPath: projectPath)
    _ = await observer.hasChangedSinceLastSnapshot()

    while !Task.isCancelled {
      try? await Task.sleep(for: .milliseconds(800))
      guard !Task.isCancelled else { return }

      if await observer.hasChangedSinceLastSnapshot() {
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }

        _ = await observer.hasChangedSinceLastSnapshot()
        reloadPreview()
      }
    }
  }
}

private struct SlideDeckThumbnailButton: View {
  let slide: SlideDeckSlide
  let thumbnail: NSImage?
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 8) {
        Text("\(slide.index + 1)")
          .font(.caption.weight(.semibold))
          .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.52))
          .frame(width: 18, alignment: .trailing)
          .padding(.top, 2)

        ZStack {
          RoundedRectangle(cornerRadius: 4)
            .fill(Color.white.opacity(0.10))

          if let thumbnail {
            Image(nsImage: thumbnail)
              .resizable()
              .aspectRatio(16 / 9, contentMode: .fill)
              .frame(width: 96, height: 54)
              .clipped()
          } else {
            VStack(spacing: 4) {
              Image(systemName: "rectangle")
                .font(.system(size: 15, weight: .medium))
              Text(slide.title)
                .font(.system(size: 8, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 5)
            }
            .foregroundStyle(Color.white.opacity(0.44))
          }
        }
        .frame(width: 96, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay {
          RoundedRectangle(cornerRadius: 4)
            .stroke(
              isSelected ? EaselDesignSystem.Palette.accent : Color.white.opacity(0.12),
              lineWidth: isSelected ? 2 : 1
            )
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help(slide.title)
    .accessibilityLabel("Slide \(slide.index + 1), \(slide.title)")
  }
}
