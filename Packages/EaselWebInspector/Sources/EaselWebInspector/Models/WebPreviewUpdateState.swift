//
//  WebPreviewUpdateState.swift
//  EaselWebInspector
//
//  Manual update state for the web preview footer.
//

import Foundation

@MainActor
public enum WebPreviewUpdateState: Equatable {
  case hidden
  case available(detail: String)
  case unavailable(detail: String)

  public static func resolve(
    hasPreview: Bool,
    isEditMode: Bool
  ) -> WebPreviewUpdateState {
    guard isEditMode else {
      return .hidden
    }

    if hasPreview {
      return .available(detail: "Design and code preview updates are manual. Save changes, then press Reload.")
    }

    return .unavailable(detail: "Reload will be available when the preview is ready.")
  }

  public var detailText: String {
    switch self {
    case .hidden:
      ""
    case .available(let detail), .unavailable(let detail):
      detail
    }
  }

  public var isVisible: Bool {
    switch self {
    case .hidden:
      false
    case .available, .unavailable:
      true
    }
  }

  public var isEnabled: Bool {
    switch self {
    case .available:
      true
    case .hidden, .unavailable:
      false
    }
  }

  public func performUpdate(
    flushPendingWrites: () async -> Void,
    reload: () -> Void
  ) async {
    guard isEnabled else { return }
    await flushPendingWrites()
    reload()
  }
}
