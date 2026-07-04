//
//  WebPreviewProvenanceLiveWebViewTests.swift
//  EaselWebInspectorTests
//
//  Runs the provenance and environment scripts against a real WKWebView
//  rendering a real page — the end-to-end proof that a plain-CSS page
//  yields provable winners, an insertion anchor, and a usable unit
//  environment, and that constructed stylesheets are detected.
//

import Foundation
import Testing
import WebKit

@testable import EaselWebInspector

@MainActor
@Suite("Provenance script against a live WKWebView")
struct WebPreviewProvenanceLiveWebViewTests {

  private struct LoadTimeout: Error {}

  /// Loads the page and waits until `marker` is queryable. Polling
  /// readyState is not enough: right after loadHTMLString the *previous*
  /// (blank) document still reports "complete".
  private func loadPage(_ html: String, marker: String = ".cta") async throws -> WKWebView {
    let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1000, height: 700))
    webView.loadHTMLString(html, baseURL: URL(string: "http://localhost/")!)
    let probe = "!!document.querySelector('\(marker)')"
    var waited = 0
    while waited < 5_000 {
      if let found = try? await webView.evaluateJavaScript(probe) as? Bool, found {
        return webView
      }
      try await Task.sleep(for: .milliseconds(25))
      waited += 25
    }
    throw LoadTimeout()
  }

  @Test("A plain-CSS page yields provable winners and an insertion anchor")
  func plainPageYieldsWinnersAndAnchor() async throws {
    let webView = try await loadPage("""
    <html><head><style>
      .cta { background-color: #112233; padding: 4px; }
    </style></head><body><button class="cta">Go</button></body></html>
    """)

    let provenance = await WebPreviewStyleProvenanceCapture().captureProvenance(
      selector: ".cta",
      properties: ["background-color", "font-size"],
      in: webView
    )

    let captured = try #require(provenance)
    #expect(captured.hasAdoptedSheets == false)
    #expect(captured.unreadableSheetHrefs.isEmpty)

    // background-color is declared by a plain rule: a provable winner.
    let winner = try #require(captured.winner(for: "background-color"))
    #expect(winner.isInline == false)
    #expect(winner.uncertainties.isEmpty)
    #expect(winner.rule?.selectorText == ".cta")
    #expect(winner.rule?.ruleIndexPath == [0])

    // font-size comes from browser defaults: no winner, but the anchor rule
    // gives a deterministic insertion point.
    #expect(captured.winner(for: "font-size") == nil)
    let anchor = try #require(captured.anchorRule)
    #expect(anchor.selectorText == ".cta")
    #expect(anchor.ruleIndexPath == [0])

    let environment = await WebPreviewPageEnvironmentCapture().captureEnvironment(
      selector: ".cta",
      in: webView
    )
    let capturedEnvironment = try #require(environment)
    #expect(capturedEnvironment.viewportWidth > 0)
    #expect(capturedEnvironment.rootFontSize > 0)
  }

  @Test("Constructed stylesheets are detected so insertion stays conservative")
  func constructedStylesheetsDetected() async throws {
    let webView = try await loadPage("""
    <html><head><style>.cta { padding: 4px; }</style>
    <script>
      const sheet = new CSSStyleSheet();
      sheet.replaceSync('.cta { color: red; }');
      document.adoptedStyleSheets = [sheet];
    </script></head><body><button class="cta">Go</button></body></html>
    """)

    let provenance = await WebPreviewStyleProvenanceCapture().captureProvenance(
      selector: ".cta",
      properties: ["color"],
      in: webView
    )

    let captured = try #require(provenance)
    #expect(captured.hasAdoptedSheets == true)
  }
}
