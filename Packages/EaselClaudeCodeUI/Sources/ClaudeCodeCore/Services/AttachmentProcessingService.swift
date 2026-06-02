//
//  AttachmentProcessingService.swift
//  ClaudeCodeUI
//

import Foundation

public protocol AttachmentProcessingService: Sendable {
  func process(_ attachment: FileAttachment) async
  func processAttachments(_ attachments: [FileAttachment]) async
}

extension AttachmentProcessor: AttachmentProcessingService {}
