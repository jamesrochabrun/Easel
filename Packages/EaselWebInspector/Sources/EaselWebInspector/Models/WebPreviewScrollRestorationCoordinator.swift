//
//  WebPreviewScrollRestorationCoordinator.swift
//  EaselWebInspector
//
//  Coordinates app-triggered web preview reloads so scroll position can be
//  captured before reload and restored after navigation completes.
//

import Foundation

public struct WebPreviewScrollRestorationCoordinator: Equatable {
  public private(set) var effectiveReloadToken: UUID?
  public private(set) var pendingRequestedReloadToken: UUID?
  public private(set) var pendingScrollPosition: WebPreviewScrollPosition?
  public private(set) var isCapturingScrollPosition = false
  public private(set) var suppressesSelectorRestore = false

  public init() {}

  public mutating func reset(to token: UUID?) {
    effectiveReloadToken = token
    pendingRequestedReloadToken = nil
    pendingScrollPosition = nil
    isCapturingScrollPosition = false
    suppressesSelectorRestore = false
  }

  public mutating func queueReload(token: UUID?) {
    guard let token, token != effectiveReloadToken else {
      return
    }

    pendingRequestedReloadToken = token
  }

  public mutating func beginCaptureIfNeeded() -> Bool {
    guard let pendingRequestedReloadToken else { return false }
    guard pendingRequestedReloadToken != effectiveReloadToken else {
      self.pendingRequestedReloadToken = nil
      return false
    }
    guard !isCapturingScrollPosition else { return false }

    isCapturingScrollPosition = true
    return true
  }

  @discardableResult
  public mutating func finishCapture(with scrollPosition: WebPreviewScrollPosition?) -> UUID? {
    guard isCapturingScrollPosition else { return nil }

    isCapturingScrollPosition = false
    guard let pendingRequestedReloadToken,
          pendingRequestedReloadToken != effectiveReloadToken else {
      self.pendingRequestedReloadToken = nil
      pendingScrollPosition = nil
      return nil
    }

    effectiveReloadToken = pendingRequestedReloadToken
    self.pendingRequestedReloadToken = nil
    pendingScrollPosition = scrollPosition
    suppressesSelectorRestore = true
    return effectiveReloadToken
  }

  public mutating func consumePendingScrollPosition() -> WebPreviewScrollPosition? {
    suppressesSelectorRestore = false
    defer { pendingScrollPosition = nil }
    return pendingScrollPosition
  }
}
