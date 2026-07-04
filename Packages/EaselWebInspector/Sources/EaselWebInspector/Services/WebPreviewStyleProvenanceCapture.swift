//
//  WebPreviewStyleProvenanceCapture.swift
//  EaselWebInspector
//
//  Evaluates the provenance script in the preview web view and parses the
//  result. Protocol-backed so view-model tests can inject fixtures.
//

import Foundation
import WebKit
import os

private let provenanceLog = Logger(subsystem: "com.easel.webinspector", category: "WebPreviewStyleProvenanceCapture")

@MainActor
public protocol WebPreviewStyleProvenanceCapturing {
  func captureProvenance(
    selector: String,
    properties: [String],
    in webView: WKWebView
  ) async -> WebPreviewStyleProvenance?
}

@MainActor
public protocol WebPreviewSourceHintCapturing {
  func captureSourceHints(
    selector: String,
    in webView: WKWebView
  ) async -> [WebPreviewElementSourceHint]
}

@MainActor
public struct WebPreviewStyleProvenanceCapture: WebPreviewStyleProvenanceCapturing {
  public init() {}

  public func captureProvenance(
    selector: String,
    properties: [String],
    in webView: WKWebView
  ) async -> WebPreviewStyleProvenance? {
    guard let script = WebPreviewStyleProvenanceScript.script(
      selector: selector,
      properties: properties
    ) else {
      return nil
    }

    let result: Any? = await withCheckedContinuation { continuation in
      webView.evaluateJavaScript(script) { value, error in
        if let error {
          provenanceLog.debug(
            "[WebPreview] Style provenance script failed: \(error.localizedDescription, privacy: .public)"
          )
          continuation.resume(returning: nil)
          return
        }
        continuation.resume(returning: value)
      }
    }

    return WebPreviewStyleProvenance.parse(result)
  }
}

@MainActor
public struct WebPreviewSourceHintCapture: WebPreviewSourceHintCapturing {
  public init() {}

  public func captureSourceHints(
    selector: String,
    in webView: WKWebView
  ) async -> [WebPreviewElementSourceHint] {
    guard let script = WebPreviewSourceHintScript.script(selector: selector) else {
      return []
    }

    let result: Any? = await withCheckedContinuation { continuation in
      webView.evaluateJavaScript(script) { value, error in
        if error != nil {
          continuation.resume(returning: nil)
          return
        }
        continuation.resume(returning: value)
      }
    }

    return WebPreviewElementSourceHint.parse(result)
  }
}
