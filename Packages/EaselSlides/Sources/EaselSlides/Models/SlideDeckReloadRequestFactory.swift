//
//  SlideDeckReloadRequestFactory.swift
//  EaselSlides
//

import Foundation

enum SlideDeckReloadRequestFactory {
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

  private static func previewableDocumentURL(_ url: URL) -> URL? {
    let path = url.path
    if path.isEmpty || path == "/" { return url }

    let fileExtension = (url.lastPathComponent as NSString).pathExtension.lowercased()
    if !fileExtension.isEmpty {
      return ["html", "htm"].contains(fileExtension) ? url : nil
    }

    return url.absoluteString.hasSuffix("/") ? nil : url
  }
}
