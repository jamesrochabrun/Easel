//
//  SlideDeckThumbnailRenderer.swift
//  EaselWebInspector
//

import AppKit
import SwiftUI
import WebKit

struct SlideDeckThumbnailRenderer: NSViewRepresentable {
  let url: URL
  let cacheKey: SlideDeckThumbnailCacheKey
  let onThumbnailsRendered: @MainActor (SlideDeckThumbnailCacheKey, [Int: NSImage]) -> Void

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.allowsMagnification = false
    webView.allowsBackForwardNavigationGestures = false
    webView.setValue(false, forKey: "drawsBackground")

    context.coordinator.webView = webView
    context.coordinator.load(url, in: webView)
    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {
    context.coordinator.parent = self

    if context.coordinator.lastLoadedURL != url
      || context.coordinator.lastCacheKey?.reloadToken != cacheKey.reloadToken {
      context.coordinator.load(url, in: webView)
      return
    }

    if context.coordinator.lastCacheKey != cacheKey,
       context.coordinator.hasFinishedLoading {
      context.coordinator.renderThumbnails()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
    coordinator.cancel()
    nsView.navigationDelegate = nil
    nsView.stopLoading()
  }

  @MainActor
  final class Coordinator: NSObject, WKNavigationDelegate {
    var parent: SlideDeckThumbnailRenderer
    weak var webView: WKWebView?
    var lastLoadedURL: URL?
    var lastCacheKey: SlideDeckThumbnailCacheKey?
    var hasFinishedLoading = false

    private var renderTask: Task<Void, Never>?

    init(parent: SlideDeckThumbnailRenderer) {
      self.parent = parent
    }

    func load(_ url: URL, in webView: WKWebView) {
      cancel()
      hasFinishedLoading = false
      lastLoadedURL = url
      lastCacheKey = nil
      webView.load(URLRequest(url: WebPreviewReloadRequestFactory.cacheBypassedURL(
        for: url,
        token: parent.cacheKey.reloadToken
      )))
    }

    func renderThumbnails() {
      guard let webView else { return }

      cancel()
      let cacheKey = parent.cacheKey
      lastCacheKey = cacheKey

      renderTask = Task { @MainActor [weak self, weak webView] in
        guard let self, let webView else { return }

        do {
          let result = try await self.evaluateJavaScript(
            SlideDeckPreviewScript.installAndSelectScript(selectedIndex: 0),
            in: webView
          )
          let metadata = SlideDeckMetadataParser.metadata(from: result)
          var thumbnails: [Int: NSImage] = [:]

          for slide in metadata.slides {
            try Task.checkCancellation()
            _ = try await self.evaluateJavaScript(
              SlideDeckPreviewScript.selectScript(index: slide.index),
              in: webView
            )
            try await Task.sleep(for: .milliseconds(80))
            try Task.checkCancellation()

            if let image = try? await self.snapshot(webView) {
              thumbnails[slide.index] = image
            }
          }

          guard !Task.isCancelled else { return }
          self.parent.onThumbnailsRendered(cacheKey, thumbnails)
        } catch is CancellationError {
          return
        } catch {
          self.parent.onThumbnailsRendered(cacheKey, [:])
        }
      }
    }

    func cancel() {
      renderTask?.cancel()
      renderTask = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      hasFinishedLoading = true
      renderThumbnails()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      parent.onThumbnailsRendered(parent.cacheKey, [:])
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      parent.onThumbnailsRendered(parent.cacheKey, [:])
    }

    private func evaluateJavaScript(_ script: String, in webView: WKWebView) async throws -> Any? {
      try await withCheckedThrowingContinuation { continuation in
        webView.evaluateJavaScript(script) { result, error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume(returning: result)
          }
        }
      }
    }

    private func snapshot(_ webView: WKWebView) async throws -> NSImage {
      let configuration = WKSnapshotConfiguration()
      configuration.rect = webView.bounds

      return try await withCheckedThrowingContinuation { continuation in
        webView.takeSnapshot(with: configuration) { image, error in
          if let image {
            continuation.resume(returning: image)
          } else {
            continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
          }
        }
      }
    }
  }
}
