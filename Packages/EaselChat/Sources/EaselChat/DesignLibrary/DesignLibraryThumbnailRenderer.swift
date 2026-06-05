//
//  DesignLibraryThumbnailRenderer.swift
//  EaselChat
//

import AppKit
import EaselSlides
import SwiftUI
import WebKit

struct DesignLibraryThumbnailRenderer: NSViewRepresentable {
  let previewFile: DesignLibraryPreviewFile
  let kind: DesignLibraryItemKind
  let cacheKey: DesignLibraryThumbnailCacheKey
  let onRendered: @MainActor (DesignLibraryThumbnailCacheKey, NSImage) -> Void
  let onFailed: @MainActor (DesignLibraryThumbnailCacheKey) -> Void

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    let webView = WKWebView(
      frame: CGRect(origin: .zero, size: DesignLibraryThumbnailMetrics.renderSize),
      configuration: configuration
    )
    webView.navigationDelegate = context.coordinator
    webView.allowsBackForwardNavigationGestures = false
    webView.allowsMagnification = false
    webView.setValue(false, forKey: "drawsBackground")

    context.coordinator.webView = webView
    context.coordinator.load(previewFile, in: webView)
    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {
    context.coordinator.parent = self

    if context.coordinator.lastCacheKey != cacheKey {
      context.coordinator.load(previewFile, in: webView)
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
    var parent: DesignLibraryThumbnailRenderer
    weak var webView: WKWebView?
    var lastCacheKey: DesignLibraryThumbnailCacheKey?

    private var renderTask: Task<Void, Never>?

    init(parent: DesignLibraryThumbnailRenderer) {
      self.parent = parent
    }

    func load(_ previewFile: DesignLibraryPreviewFile, in webView: WKWebView) {
      cancel()
      lastCacheKey = parent.cacheKey
      webView.loadFileURL(previewFile.url, allowingReadAccessTo: previewFile.readAccessURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      renderThumbnail()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      parent.onFailed(parent.cacheKey)
      cancel()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      parent.onFailed(parent.cacheKey)
      cancel()
    }

    func cancel() {
      renderTask?.cancel()
      renderTask = nil
    }

    private func renderThumbnail() {
      guard let webView else { return }

      cancel()
      let request = parent
      renderTask = Task { @MainActor [weak self, weak webView] in
        guard let self, let webView else { return }

        do {
          if request.kind.preparesSlideFirstPage {
            _ = try await evaluateJavaScript(
              SlideDeckFirstSlidePreparationScript.script,
              in: webView
            )
          }

          try await waitForNextPaint(in: webView)
          try Task.checkCancellation()

          let image = try await snapshot(webView)
          request.onRendered(request.cacheKey, image)
        } catch is CancellationError {
          return
        } catch {
          request.onFailed(request.cacheKey)
        }
      }
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
      if webView.bounds.isEmpty {
        webView.frame = CGRect(origin: .zero, size: DesignLibraryThumbnailMetrics.renderSize)
      }

      let configuration = WKSnapshotConfiguration()
      configuration.rect = webView.bounds
      configuration.snapshotWidth = NSNumber(value: Double(DesignLibraryThumbnailMetrics.snapshotWidth))

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
          setTimeout(resolve, \(DesignLibraryThumbnailMetrics.fontReadinessTimeoutMilliseconds));
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
