//
//  SlideDeckReloadRequestFactoryTests.swift
//  EaselSlidesTests
//

import Foundation
import Testing
@testable import EaselSlides

@Suite("SlideDeckReloadRequestFactory")
struct SlideDeckReloadRequestFactoryTests {
  @Test
  func cacheBypassedURLAddsReloadToken() {
    let url = URL(string: "http://localhost:4100/index.html")!
    let token = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    let reloadedURL = SlideDeckReloadRequestFactory.cacheBypassedURL(for: url, token: token)

    #expect(reloadedURL.absoluteString == "http://localhost:4100/index.html?easelReload=00000000-0000-0000-0000-000000000001")
  }

  @Test
  func cacheBypassedURLReplacesExistingReloadToken() {
    let url = URL(string: "http://localhost:4100/?easelReload=old&theme=dark")!
    let token = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    let reloadedURL = SlideDeckReloadRequestFactory.cacheBypassedURL(for: url, token: token)

    #expect(reloadedURL.absoluteString == "http://localhost:4100/?theme=dark&easelReload=00000000-0000-0000-0000-000000000002")
  }

  @Test
  func requestReloadsCurrentHTMLDocumentOnSameOrigin() {
    let currentURL = URL(string: "http://localhost:4100/slides/index.html")!
    let fallbackURL = URL(string: "http://localhost:4100/")!
    let token = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    let request = SlideDeckReloadRequestFactory.request(
      currentURL: currentURL,
      fallbackURL: fallbackURL,
      token: token
    )

    #expect(request.url?.absoluteString == "http://localhost:4100/slides/index.html?easelReload=00000000-0000-0000-0000-000000000003")
    #expect(request.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
  }

  @Test
  func requestFallsBackWhenCurrentURLIsStaticAsset() {
    let currentURL = URL(string: "http://localhost:4100/resources/hero.png")!
    let fallbackURL = URL(string: "http://localhost:4100/")!
    let token = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    let request = SlideDeckReloadRequestFactory.request(
      currentURL: currentURL,
      fallbackURL: fallbackURL,
      token: token
    )

    #expect(request.url?.absoluteString == "http://localhost:4100/?easelReload=00000000-0000-0000-0000-000000000004")
  }
}
