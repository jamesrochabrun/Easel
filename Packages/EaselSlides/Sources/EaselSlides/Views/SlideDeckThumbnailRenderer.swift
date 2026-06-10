//
//  SlideDeckThumbnailRenderer.swift
//  EaselSlides
//

import AppKit
import SwiftUI
import WebKit

struct SlideDeckThumbnailRenderer: NSViewRepresentable {
  let url: URL
  let cacheKey: SlideDeckThumbnailCacheKey
  let metadata: SlideDeckMetadata
  let selectedIndex: Int
  let onThumbnailRendered: @MainActor (SlideDeckThumbnailCacheKey, Int, NSImage) -> Void

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.allowsMagnification = false
    webView.allowsBackForwardNavigationGestures = false
    webView.setValue(false, forKey: "drawsBackground")

    context.coordinator.webView = webView
    context.coordinator.load(url, in: webView, bypassingCache: false)
    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {
    context.coordinator.parent = self

    let urlChanged = context.coordinator.lastLoadedURL != url
    let reloadTokenChanged = context.coordinator.lastLoadedReloadToken != cacheKey.reloadToken

    if urlChanged || reloadTokenChanged {
      context.coordinator.load(
        url,
        in: webView,
        bypassingCache: reloadTokenChanged
      )
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
    var lastLoadedReloadToken: UUID?
    var lastCacheKey: SlideDeckThumbnailCacheKey?
    var hasFinishedLoading = false

    private var renderTask: Task<Void, Never>?

    init(parent: SlideDeckThumbnailRenderer) {
      self.parent = parent
    }

    func load(_ url: URL, in webView: WKWebView, bypassingCache: Bool) {
      cancel()
      hasFinishedLoading = false
      lastLoadedURL = url
      lastLoadedReloadToken = parent.cacheKey.reloadToken
      lastCacheKey = nil

      if bypassingCache {
        webView.load(URLRequest(url: SlideDeckReloadRequestFactory.cacheBypassedURL(
          for: url,
          token: parent.cacheKey.reloadToken
        )))
      } else {
        webView.load(URLRequest(url: url))
      }
    }

    func renderThumbnails() {
      guard let webView else { return }

      cancel()
      let request = parent
      let cacheKey = request.cacheKey
      lastCacheKey = cacheKey

      renderTask = Task { @MainActor [weak self, weak webView] in
        guard let self, let webView else { return }

        do {
          let result = try await self.evaluateJavaScript(
            SlideDeckPreviewScript.installAndSelectScript(
              selectedIndex: request.selectedIndex,
              fastForwardMotion: true
            ),
            in: webView
          )
          let discoveredMetadata = SlideDeckMetadataParser.metadata(from: result)
          let slides = request.metadata.isEmpty ? discoveredMetadata.slides : request.metadata.slides
          let orderedSlides = SlideDeckThumbnailRenderPlan.orderedSlides(
            from: slides,
            selectedIndex: request.selectedIndex
          )

          for slide in orderedSlides {
            try Task.checkCancellation()
            _ = try await self.evaluateJavaScript(
              SlideDeckPreviewScript.selectScript(index: slide.index),
              in: webView
            )
            try await self.waitForNextPaint(in: webView)
            try Task.checkCancellation()

            if let image = try? await self.snapshot(webView) {
              self.parent.onThumbnailRendered(cacheKey, slide.index, image)
            }
          }
        } catch is CancellationError {
          return
        } catch {
          return
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
      cancel()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      cancel()
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
      configuration.snapshotWidth = NSNumber(
        value: Double(SlideDeckThumbnailRenderPlan.snapshotWidth)
      )

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

    private func waitForNextPaint(in webView: WKWebView) async throws {
      _ = try await webView.callAsyncJavaScript(
        """
        const timeout = new Promise((resolve) => {
          setTimeout(resolve, \(SlideDeckThumbnailRenderPlan.fontReadinessTimeoutMilliseconds));
        });
        const fontsReady = document.fonts && document.fonts.ready
          ? document.fonts.ready.catch(() => undefined)
          : Promise.resolve();
        await Promise.race([fontsReady, timeout]);
        await new Promise((resolve) => requestAnimationFrame(resolve));
        return true;
        """,
        arguments: [:],
        in: nil,
        contentWorld: .page
      )
    }
  }
}
