//
//  StaticFileServer.swift
//  EaselServerManager
//

import Foundation
import Network
import OSLog

private let serverLog = Logger(
  subsystem: "com.easel.servermanager",
  category: "StaticFileServer"
)

final class StaticFileServer: Sendable {

  let port: UInt16
  let rootDirectory: String
  private let listener: NWListener

  init(port: UInt16, rootDirectory: String) throws {
    self.port = port
    self.rootDirectory = rootDirectory
    let params = NWParameters.tcp
    self.listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
  }

  func start() {
    listener.newConnectionHandler = { [rootDirectory] connection in
      Self.handleConnection(connection, rootDirectory: rootDirectory)
    }
    listener.stateUpdateHandler = { state in
      switch state {
      case .ready:
        serverLog.info("Server listening on port \(self.port)")
      case .failed(let error):
        serverLog.error("Server failed on port \(self.port): \(error.localizedDescription)")
      default:
        break
      }
    }
    listener.start(queue: .global(qos: .utility))
  }

  func stop() {
    listener.cancel()
    serverLog.info("Server stopped on port \(self.port)")
  }

  // MARK: - Connection Handling

  private static func handleConnection(
    _ connection: NWConnection,
    rootDirectory: String
  ) {
    connection.start(queue: .global(qos: .utility))
    connection.receive(
      minimumIncompleteLength: 1,
      maximumLength: 65536
    ) { data, _, _, error in
      defer { connection.cancel() }

      guard let data, error == nil else { return }

      let requestString = String(data: data, encoding: .utf8) ?? ""
      let response = Self.handleRequest(requestString, rootDirectory: rootDirectory)

      connection.send(
        content: response,
        completion: .contentProcessed { _ in
          connection.cancel()
        }
      )
    }
  }

  static func handleRequest(
    _ request: String,
    rootDirectory: String
  ) -> Data {
    let lines = request.components(separatedBy: "\r\n")
    guard let requestLine = lines.first else {
      return HTTPResponseBuilder.errorResponse("Invalid request")
    }

    let parts = requestLine.split(separator: " ")
    guard parts.count >= 2 else {
      return HTTPResponseBuilder.errorResponse("Invalid request line")
    }

    var requestPath = String(parts[1])

    if let decoded = requestPath.removingPercentEncoding {
      requestPath = decoded
    }

    // Strip query string
    if let queryIndex = requestPath.firstIndex(of: "?") {
      requestPath = String(requestPath[..<queryIndex])
    }

    if requestPath == "/" {
      requestPath = "/index.html"
    }

    // Prevent directory traversal
    let normalized = requestPath
      .replacingOccurrences(of: "..", with: "")
      .replacingOccurrences(of: "//", with: "/")

    let filePath = (rootDirectory as NSString)
      .appendingPathComponent(normalized)

    // If path is a directory, serve its index.html
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(
      atPath: filePath,
      isDirectory: &isDirectory
    )

    let finalPath: String
    if exists && isDirectory.boolValue {
      finalPath = (filePath as NSString).appendingPathComponent("index.html")
    } else {
      finalPath = filePath
    }

    guard FileManager.default.fileExists(atPath: finalPath) else {
      // SPA fallback: serve root index.html for paths without file extensions
      let ext = (finalPath as NSString).pathExtension
      if ext.isEmpty {
        let indexPath = (rootDirectory as NSString)
          .appendingPathComponent("index.html")
        if let indexData = FileManager.default.contents(atPath: indexPath) {
          return HTTPResponseBuilder.buildResponse(
            statusCode: 200,
            statusText: "OK",
            contentType: "text/html; charset=utf-8",
            body: indexData
          )
        }
      }
      return HTTPResponseBuilder.notFoundResponse()
    }

    guard let fileData = FileManager.default.contents(atPath: finalPath) else {
      return HTTPResponseBuilder.errorResponse("Failed to read file")
    }

    let ext = (finalPath as NSString).pathExtension
    let contentType = HTTPResponseBuilder.mimeType(for: ext)

    return HTTPResponseBuilder.buildResponse(
      statusCode: 200,
      statusText: "OK",
      contentType: contentType,
      body: fileData
    )
  }
}
