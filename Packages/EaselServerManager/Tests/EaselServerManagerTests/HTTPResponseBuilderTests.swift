//
//  HTTPResponseBuilderTests.swift
//  EaselServerManagerTests
//

@testable import EaselServerManager
import Foundation
import Testing

@Suite
struct HTTPResponseBuilderTests {

  @Test
  func mimeTypeForHTML() {
    #expect(HTTPResponseBuilder.mimeType(for: "html") == "text/html; charset=utf-8")
  }

  @Test
  func mimeTypeForCSS() {
    #expect(HTTPResponseBuilder.mimeType(for: "css") == "text/css; charset=utf-8")
  }

  @Test
  func mimeTypeForJS() {
    #expect(HTTPResponseBuilder.mimeType(for: "js") == "application/javascript; charset=utf-8")
  }

  @Test
  func mimeTypeForJSON() {
    #expect(HTTPResponseBuilder.mimeType(for: "json") == "application/json; charset=utf-8")
  }

  @Test
  func mimeTypeForPNG() {
    #expect(HTTPResponseBuilder.mimeType(for: "png") == "image/png")
  }

  @Test
  func mimeTypeForSVG() {
    #expect(HTTPResponseBuilder.mimeType(for: "svg") == "image/svg+xml")
  }

  @Test
  func mimeTypeIsCaseInsensitive() {
    #expect(HTTPResponseBuilder.mimeType(for: "HTML") == "text/html; charset=utf-8")
    #expect(HTTPResponseBuilder.mimeType(for: "Css") == "text/css; charset=utf-8")
  }

  @Test
  func mimeTypeForUnknownExtension() {
    #expect(HTTPResponseBuilder.mimeType(for: "xyz") == "application/octet-stream")
  }

  @Test
  func buildResponseIncludesStatusLine() {
    let response = HTTPResponseBuilder.buildResponse(
      statusCode: 200,
      statusText: "OK",
      contentType: "text/plain",
      body: Data("hello".utf8)
    )
    let text = String(data: response, encoding: .utf8)!
    #expect(text.hasPrefix("HTTP/1.1 200 OK"))
  }

  @Test
  func buildResponseIncludesHeaders() {
    let response = HTTPResponseBuilder.buildResponse(
      statusCode: 200,
      statusText: "OK",
      contentType: "text/plain",
      body: Data("hello".utf8)
    )
    let text = String(data: response, encoding: .utf8)!
    #expect(text.contains("Content-Type: text/plain"))
    #expect(text.contains("Content-Length: 5"))
    #expect(text.contains("Access-Control-Allow-Origin: *"))
    #expect(text.contains("Cache-Control: no-cache"))
  }

  @Test
  func buildResponseIncludesBody() {
    let response = HTTPResponseBuilder.buildResponse(
      statusCode: 200,
      statusText: "OK",
      contentType: "text/plain",
      body: Data("hello world".utf8)
    )
    let text = String(data: response, encoding: .utf8)!
    #expect(text.contains("hello world"))
  }

  @Test
  func notFoundResponseContains404() {
    let response = HTTPResponseBuilder.notFoundResponse()
    let text = String(data: response, encoding: .utf8)!
    #expect(text.contains("404"))
    #expect(text.contains("Not Found"))
  }

  @Test
  func errorResponseContains500() {
    let response = HTTPResponseBuilder.errorResponse("something broke")
    let text = String(data: response, encoding: .utf8)!
    #expect(text.contains("500"))
    #expect(text.contains("Internal Server Error"))
  }
}
