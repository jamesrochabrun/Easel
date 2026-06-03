//
//  PreviewURLObserver.swift
//  EaselChat
//

import ClaudeCodeCore
import Foundation
import OSLog

private let previewLog = Logger(subsystem: "com.easel.chat", category: "PreviewURLObserver")

@MainActor
final class PreviewURLObserver {
  private let extractor: URLExtracting
  private var isObserving = false

  init(extractor: URLExtracting = LocalhostURLExtractor()) {
    self.extractor = extractor
  }

  func startObserving(
    messages: @escaping @MainActor () -> [ChatMessage],
    onURLDetected: @escaping @MainActor (URL) -> Void
  ) {
    guard !isObserving else { return }
    isObserving = true
    previewLog.debug("Started observing for preview URLs")
    observe(messages: messages, onURLDetected: onURLDetected)
  }

  func stopObserving() {
    isObserving = false
  }

  private func observe(
    messages: @escaping @MainActor () -> [ChatMessage],
    onURLDetected: @escaping @MainActor (URL) -> Void
  ) {
    withObservationTracking {
      _ = messages()
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self, self.isObserving else { return }
        self.scanForURLs(in: messages(), onURLDetected: onURLDetected)
        // scanForURLs stops observation once a URL is found; don't re-arm in that case.
        guard self.isObserving else { return }
        self.observe(messages: messages, onURLDetected: onURLDetected)
      }
    }
  }

  /// Performs an immediate scan of the given messages for a localhost URL.
  /// Returns the detected URL, or nil if none found.
  func scanExistingMessages(_ messages: [ChatMessage]) -> URL? {
    previewLog.debug("Scanning \(messages.count) messages for preview URL")
    let rescanStart = max(0, messages.count - 5)
    let recentMessages = Array(messages.suffix(from: rescanStart))

    for messageType: MessageType in [.toolResult, .text] {
      for message in recentMessages.reversed() {
        guard message.messageType == messageType else { continue }
        let preview = message.content.prefix(200)
        previewLog.debug("Checking [\(messageType.rawValue)] content: \(preview)")
        if let url = extractor.extractPreviewURL(from: message.content) {
          previewLog.info("Detected preview URL: \(url.absoluteString)")
          return url
        }
      }
    }
    previewLog.debug("No preview URL found in messages")
    return nil
  }

  private func scanForURLs(
    in messages: [ChatMessage],
    onURLDetected: @escaping @MainActor (URL) -> Void
  ) {
    guard let url = scanExistingMessages(messages) else { return }
    // One-shot: a preview URL was found, so stop the per-message rescans.
    stopObserving()
    onURLDetected(url)
  }
}
