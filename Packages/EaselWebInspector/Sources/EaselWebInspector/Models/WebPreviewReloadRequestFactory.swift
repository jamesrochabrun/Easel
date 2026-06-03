//
//  WebPreviewReloadRequestFactory.swift
//  EaselWebInspector
//

import Foundation

enum WebPreviewReloadRequestFactory {
  private static let reloadQueryItemName = "easelReload"

  static func request(
    currentURL: URL?,
    fallbackURL: URL,
    token: UUID = UUID()
  ) -> URLRequest {
    let baseURL = currentURL
      .flatMap { sameOriginURL($0, as: fallbackURL) }
      .flatMap(previewableDocumentURL) ?? fallbackURL
    return URLRequest(
      url: cacheBypassedURL(for: baseURL, token: token),
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
      timeoutInterval: 30
    )
  }

  static func cacheBypassedURL(for url: URL, token: UUID) -> URL {
    guard !url.isFileURL,
          var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return url
    }

    var queryItems = components.queryItems?.filter { $0.name != reloadQueryItemName } ?? []
    queryItems.append(URLQueryItem(name: reloadQueryItemName, value: token.uuidString))
    components.queryItems = queryItems
    return components.url ?? url
  }

  private static func sameOriginURL(_ url: URL, as fallbackURL: URL) -> URL? {
    guard url.scheme == fallbackURL.scheme,
          url.host == fallbackURL.host,
          url.port == fallbackURL.port else {
      return nil
    }

    return url
  }

  /// Returns `url` only when it points at a page worth reloading — not a static asset
  /// (image, stylesheet, script, font…) or a non-root directory listing the webview may
  /// have drifted to. For anything else the caller falls back to the root preview URL so a
  /// freshly built page is shown instead of a stray resource (e.g. a generated hero PNG).
  private static func previewableDocumentURL(_ url: URL) -> URL? {
    let path = url.path
    if path.isEmpty || path == "/" { return url }

    let ext = (url.lastPathComponent as NSString).pathExtension.lowercased()
    if !ext.isEmpty {
      return ["html", "htm"].contains(ext) ? url : nil
    }

    // No file extension: a trailing slash in the original URL is a directory listing,
    // not the page. (`URL.path` drops the trailing slash, so inspect the raw string.)
    return url.absoluteString.hasSuffix("/") ? nil : url
  }
}
