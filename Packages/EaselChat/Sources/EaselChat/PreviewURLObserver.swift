//
//  PreviewURLObserver.swift
//  EaselChat
//

import ClaudeCodeCore
import Foundation

@MainActor
final class PreviewURLObserver {
  private let extractor: URLExtracting
  private var lastScannedCount: Int = 0
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
    observe(messages: messages, onURLDetected: onURLDetected)
  }

  func stopObserving() {
    isObserving = false
    lastScannedCount = 0
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
        self.observe(messages: messages, onURLDetected: onURLDetected)
      }
    }
  }

  private func scanForURLs(
    in messages: [ChatMessage],
    onURLDetected: @escaping @MainActor (URL) -> Void
  ) {
    lastScannedCount = messages.count

    // Scan recent messages in reverse (most recent first)
    let rescanStart = max(0, messages.count - 5)
    let recentMessages = Array(messages.suffix(from: rescanStart))

    // Prefer tool results (raw command output) — they have clean URLs
    // Fall back to text messages (Claude's prose) which may have extra formatting
    for messageType: MessageType in [.toolResult, .text] {
      for message in recentMessages.reversed() {
        guard message.messageType == messageType else { continue }
        if let url = extractor.extractPreviewURL(from: message.content) {
          onURLDetected(url)
          return
        }
      }
    }
  }
}
