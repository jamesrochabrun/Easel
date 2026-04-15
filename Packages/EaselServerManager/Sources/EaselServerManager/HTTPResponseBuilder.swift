//
//  HTTPResponseBuilder.swift
//  EaselServerManager
//

import Foundation

enum HTTPResponseBuilder {

  static let mimeTypes: [String: String] = [
    "html": "text/html; charset=utf-8",
    "htm": "text/html; charset=utf-8",
    "css": "text/css; charset=utf-8",
    "js": "application/javascript; charset=utf-8",
    "mjs": "application/javascript; charset=utf-8",
    "json": "application/json; charset=utf-8",
    "png": "image/png",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "gif": "image/gif",
    "svg": "image/svg+xml",
    "ico": "image/x-icon",
    "webp": "image/webp",
    "woff": "font/woff",
    "woff2": "font/woff2",
    "ttf": "font/ttf",
    "otf": "font/otf",
    "mp4": "video/mp4",
    "webm": "video/webm",
    "mp3": "audio/mpeg",
    "wav": "audio/wav",
    "pdf": "application/pdf",
    "xml": "application/xml",
    "txt": "text/plain; charset=utf-8",
    "map": "application/json",
    "wasm": "application/wasm",
  ]

  static func mimeType(for pathExtension: String) -> String {
    mimeTypes[pathExtension.lowercased()] ?? "application/octet-stream"
  }

  static func buildResponse(
    statusCode: Int,
    statusText: String,
    contentType: String,
    body: Data
  ) -> Data {
    let header = [
      "HTTP/1.1 \(statusCode) \(statusText)",
      "Content-Type: \(contentType)",
      "Content-Length: \(body.count)",
      "Access-Control-Allow-Origin: *",
      "Cache-Control: no-cache",
      "Connection: close",
      "",
      "",
    ].joined(separator: "\r\n")

    var response = Data(header.utf8)
    response.append(body)
    return response
  }

  static func notFoundResponse() -> Data {
    let body = Data("<h1>404 Not Found</h1>".utf8)
    return buildResponse(
      statusCode: 404,
      statusText: "Not Found",
      contentType: "text/html; charset=utf-8",
      body: body
    )
  }

  static func errorResponse(_ message: String) -> Data {
    let body = Data("<h1>500 Internal Server Error</h1>".utf8)
    return buildResponse(
      statusCode: 500,
      statusText: "Internal Server Error",
      contentType: "text/html; charset=utf-8",
      body: body
    )
  }
}
