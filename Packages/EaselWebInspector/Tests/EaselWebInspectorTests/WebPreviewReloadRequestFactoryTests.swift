//
//  WebPreviewReloadRequestFactoryTests.swift
//  EaselWebInspectorTests
//

import Foundation
import Testing
@testable import EaselWebInspector

@Suite("WebPreviewReloadRequestFactory")
struct WebPreviewReloadRequestFactoryTests {
  @Test("Adds cache-busting query item")
  func addsCacheBustingQueryItem() throws {
    let token = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let url = URL(string: "http://127.0.0.1:4173/places")!

    let reloadedURL = WebPreviewReloadRequestFactory.cacheBypassedURL(for: url, token: token)

    #expect(reloadedURL.absoluteString == "http://127.0.0.1:4173/places?easelReload=00000000-0000-0000-0000-000000000001")
  }

  @Test("Replaces existing cache-busting query item and preserves other query items")
  func replacesExistingCacheBustingQueryItem() throws {
    let token = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let url = URL(string: "http://localhost:3000/?tab=places&easelReload=old")!

    let reloadedURL = WebPreviewReloadRequestFactory.cacheBypassedURL(for: url, token: token)

    #expect(reloadedURL.absoluteString == "http://localhost:3000/?tab=places&easelReload=00000000-0000-0000-0000-000000000002")
  }

  @Test("Uses current same-origin URL instead of falling back to root")
  func usesCurrentSameOriginURL() throws {
    let token = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let request = WebPreviewReloadRequestFactory.request(
      currentURL: URL(string: "http://127.0.0.1:4173/seasons")!,
      fallbackURL: URL(string: "http://127.0.0.1:4173/")!,
      token: token
    )

    #expect(request.url?.absoluteString == "http://127.0.0.1:4173/seasons?easelReload=00000000-0000-0000-0000-000000000003")
    #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
  }

  @Test("Falls back when current URL is not the preview origin")
  func fallsBackForDifferentOrigin() throws {
    let token = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    let request = WebPreviewReloadRequestFactory.request(
      currentURL: URL(string: "https://example.com/")!,
      fallbackURL: URL(string: "http://127.0.0.1:4173/")!,
      token: token
    )

    #expect(request.url?.absoluteString == "http://127.0.0.1:4173/?easelReload=00000000-0000-0000-0000-000000000004")
  }
}
