//
//  SlideDeckPresentationView.swift
//  EaselSlides
//

import SwiftUI

struct SlideDeckPresentationView: View {
  let url: URL
  let reloadToken: UUID
  let onSelectedIndexChange: (Int) -> Void
  let onDismiss: () -> Void

  @State private var selectedIndex: Int
  @State private var metadata = SlideDeckMetadata.empty
  @State private var isLoading = false
  @State private var errorMessage: String?
  @FocusState private var isFocused: Bool

  init(
    url: URL,
    initialSelectedIndex: Int,
    reloadToken: UUID,
    onSelectedIndexChange: @escaping (Int) -> Void = { _ in },
    onDismiss: @escaping () -> Void
  ) {
    self.url = url
    self.reloadToken = reloadToken
    self.onSelectedIndexChange = onSelectedIndexChange
    self.onDismiss = onDismiss
    _selectedIndex = State(initialValue: initialSelectedIndex)
  }

  var body: some View {
    GeometryReader { proxy in
      let stageSize = presentationStageSize(in: proxy.size)
      let scale = stageSize.width / SlideDeckRenderMetrics.renderSize.width

      ZStack {
        Color.black

        SlideDeckWebView(
          url: url,
          selectedIndex: selectedIndex,
          reloadToken: reloadToken,
          onMetadataChange: handleMetadataChange,
          onLoadingChange: { isLoading = $0 },
          onError: { errorMessage = $0 }
        )
        .frame(
          width: SlideDeckRenderMetrics.renderSize.width,
          height: SlideDeckRenderMetrics.renderSize.height
        )
        .background(Color.white)
        .scaleEffect(scale, anchor: .center)
        .frame(width: stageSize.width, height: stageSize.height)

        if isLoading {
          ProgressView()
            .controlSize(.large)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }

        if let errorMessage {
          presentationErrorView(errorMessage)
        }

        VStack {
          HStack {
            Spacer()
            presentationControls
          }
          Spacer()
        }
        .padding(18)
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .background(Color.black)
    .focusable()
    .focused($isFocused)
    .onAppear {
      isFocused = true
    }
    .onKeyPress(.leftArrow) {
      selectPreviousSlide()
      return .handled
    }
    .onKeyPress(.rightArrow) {
      selectNextSlide()
      return .handled
    }
    .onKeyPress(.space) {
      selectNextSlide()
      return .handled
    }
    .onKeyPress(.escape) {
      onDismiss()
      return .handled
    }
  }

  private var presentationControls: some View {
    HStack(spacing: 8) {
      Button("Previous Slide", systemImage: "chevron.left") {
        selectPreviousSlide()
      }
      .labelStyle(.iconOnly)
      .disabled(!canSelectPreviousSlide)
      .help("Previous slide")

      Text(slideCounterText)
        .font(.caption.weight(.medium))
        .monospacedDigit()
        .foregroundStyle(.primary)
        .frame(minWidth: 48)

      Button("Next Slide", systemImage: "chevron.right") {
        selectNextSlide()
      }
      .labelStyle(.iconOnly)
      .disabled(!canSelectNextSlide)
      .help("Next slide")

      Divider()
        .frame(height: 18)

      Button("Exit Presentation", systemImage: "xmark") {
        onDismiss()
      }
      .labelStyle(.iconOnly)
      .help("Exit presentation")
    }
    .buttonStyle(.borderless)
    .controlSize(.small)
    .padding(.horizontal, 10)
    .padding(.vertical, 7)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.white.opacity(0.16), lineWidth: 1)
    }
  }

  private func presentationErrorView(_ message: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle")
        .font(.title3)
      Text(message)
        .font(.caption)
        .multilineTextAlignment(.center)
        .lineLimit(3)
    }
    .foregroundStyle(.white.opacity(0.86))
    .padding(14)
    .frame(maxWidth: 320)
    .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
  }

  private var slideCounterText: String {
    guard !metadata.slides.isEmpty else {
      return "\(selectedIndex + 1)"
    }

    return "\(selectedOffset + 1) of \(metadata.slides.count)"
  }

  private var selectedOffset: Int {
    metadata.slides.firstIndex { $0.index == selectedIndex } ?? 0
  }

  private var canSelectPreviousSlide: Bool {
    selectedOffset > 0
  }

  private var canSelectNextSlide: Bool {
    selectedOffset < metadata.slides.count - 1
  }

  private func selectPreviousSlide() {
    selectSlide(at: selectedOffset - 1)
  }

  private func selectNextSlide() {
    selectSlide(at: selectedOffset + 1)
  }

  private func selectSlide(at offset: Int) {
    guard metadata.slides.indices.contains(offset) else { return }
    let nextIndex = metadata.slides[offset].index
    selectedIndex = nextIndex
    onSelectedIndexChange(nextIndex)
  }

  private func presentationStageSize(in containerSize: CGSize) -> CGSize {
    let availableWidth = max(containerSize.width, 1)
    let availableHeight = max(containerSize.height, 1)
    let width = min(availableWidth, availableHeight * SlideDeckRenderMetrics.aspectRatio)
    let height = width / SlideDeckRenderMetrics.aspectRatio
    return CGSize(width: width, height: height)
  }

  @MainActor
  private func handleMetadataChange(_ nextMetadata: SlideDeckMetadata) {
    metadata = nextMetadata

    guard !nextMetadata.slides.isEmpty else {
      selectedIndex = 0
      onSelectedIndexChange(0)
      return
    }

    if !nextMetadata.slides.contains(where: { $0.index == selectedIndex }) {
      let nextIndex = nextMetadata.slides[0].index
      selectedIndex = nextIndex
      onSelectedIndexChange(nextIndex)
    }
  }
}
