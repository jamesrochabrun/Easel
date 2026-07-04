//
//  WebPreviewLiveEditApplier.swift
//  EaselWebInspector
//
//  Applies source-backed design edits to the live Canvas preview.
//

import Canvas
import WebKit

public protocol WebPreviewLiveEditApplying {
  @MainActor
  func apply(_ edit: DesignEdit, in webView: WKWebView?)

  @MainActor
  func refreshSelectedElement(in webView: WKWebView?)
}

public struct CanvasWebPreviewLiveEditApplier: WebPreviewLiveEditApplying {
  public init() {}

  @MainActor
  public func apply(_ edit: DesignEdit, in webView: WKWebView?) {
    guard let webView else { return }
    ElementInspectorBridge.applyDesignEdit(edit, in: webView)
  }

  @MainActor
  public func refreshSelectedElement(in webView: WKWebView?) {
    guard let webView else { return }
    ElementInspectorBridge.refreshSelectedElement(in: webView)
  }
}
