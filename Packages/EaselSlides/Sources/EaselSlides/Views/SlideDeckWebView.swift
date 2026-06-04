//
//  SlideDeckWebView.swift
//  EaselSlides
//

import AppKit
import SwiftUI
import WebKit

struct SlideDeckWebView: NSViewRepresentable {
  let url: URL
  let selectedIndex: Int
  let reloadToken: UUID
  let onMetadataChange: @MainActor (SlideDeckMetadata) -> Void
  let onLoadingChange: @MainActor (Bool) -> Void
  let onError: @MainActor (String) -> Void

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    #if DEBUG
    configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
    #endif

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
    let tokenChanged = context.coordinator.lastReloadToken != reloadToken

    if urlChanged || tokenChanged {
      context.coordinator.load(url, in: webView, bypassingCache: tokenChanged)
      return
    }

    if context.coordinator.lastSelectedIndex != selectedIndex {
      context.coordinator.selectSlide(selectedIndex)
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
    var parent: SlideDeckWebView
    weak var webView: WKWebView?
    var lastLoadedURL: URL?
    var lastReloadToken: UUID?
    var lastSelectedIndex: Int?

    private var evaluationTask: Task<Void, Never>?

    init(parent: SlideDeckWebView) {
      self.parent = parent
    }

    func load(_ url: URL, in webView: WKWebView, bypassingCache: Bool) {
      cancel()
      lastLoadedURL = url
      lastReloadToken = parent.reloadToken
      lastSelectedIndex = nil
      parent.onLoadingChange(true)

      if bypassingCache {
        let request = SlideDeckReloadRequestFactory.request(
          currentURL: webView.url,
          fallbackURL: url,
          token: parent.reloadToken
        )
        Task { @MainActor in
          await clearPreviewCache(in: webView.configuration.websiteDataStore)
          guard !Task.isCancelled else { return }
          webView.load(request)
        }
      } else {
        webView.load(URLRequest(url: url))
      }
    }

    func selectSlide(_ index: Int) {
      guard let webView else { return }
      lastSelectedIndex = index
      evaluationTask?.cancel()
      evaluationTask = Task { @MainActor [weak self, weak webView] in
        guard let self, let webView else { return }

        do {
          let result = try await evaluateJavaScript(
            SlideDeckPreviewScript.selectScript(index: index),
            in: webView
          )
          self.parent.onMetadataChange(SlideDeckMetadataParser.metadata(from: result))
        } catch {
          self.parent.onError(error.localizedDescription)
        }
      }
    }

    func cancel() {
      evaluationTask?.cancel()
      evaluationTask = nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
      parent.onLoadingChange(true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      parent.onLoadingChange(false)
      installRuntimeAndSelect(parent.selectedIndex)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
      parent.onLoadingChange(false)
      parent.onError(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
      parent.onLoadingChange(false)
      parent.onError(error.localizedDescription)
    }

    private func installRuntimeAndSelect(_ index: Int) {
      guard let webView else { return }
      lastSelectedIndex = index
      evaluationTask?.cancel()
      evaluationTask = Task { @MainActor [weak self, weak webView] in
        guard let self, let webView else { return }

        do {
          let result = try await evaluateJavaScript(
            SlideDeckPreviewScript.installAndSelectScript(selectedIndex: index),
            in: webView
          )
          self.parent.onMetadataChange(SlideDeckMetadataParser.metadata(from: result))
        } catch {
          self.parent.onError(error.localizedDescription)
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

    private func clearPreviewCache(in dataStore: WKWebsiteDataStore) async {
      await withCheckedContinuation { continuation in
        dataStore.removeData(
          ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache],
          modifiedSince: .distantPast
        ) {
          continuation.resume()
        }
      }
    }
  }
}
