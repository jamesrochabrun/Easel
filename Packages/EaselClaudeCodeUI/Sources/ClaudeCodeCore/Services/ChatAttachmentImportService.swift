//
//  ChatAttachmentImportService.swift
//  ClaudeCodeUI
//

import Foundation
import UniformTypeIdentifiers

public protocol ChatAttachmentImportService: Sendable {
  var acceptedContentTypes: [UTType] { get }

  func attachments(from urls: [URL]) async -> [FileAttachment]
  func attachments(from providers: [NSItemProvider]) async -> [FileAttachment]
}
