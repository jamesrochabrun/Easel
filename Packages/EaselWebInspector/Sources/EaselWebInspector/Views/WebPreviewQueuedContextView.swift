//
//  WebPreviewQueuedContextView.swift
//  EaselWebInspector
//
//  Passive queue panel shown below the preview while web-preview updates are pending.
//

import AppKit
import SwiftUI

public struct WebPreviewQueuedContextView: View {
  let queuedItems: [WebPreviewQueuedUpdate]
  let failureMessage: String?
  let onRemoveItem: (UUID) -> Void
  let onSendAll: () -> Void
  let onClearAll: () -> Void

  public init(
    queuedItems: [WebPreviewQueuedUpdate],
    failureMessage: String?,
    onRemoveItem: @escaping (UUID) -> Void,
    onSendAll: @escaping () -> Void,
    onClearAll: @escaping () -> Void
  ) {
    self.queuedItems = queuedItems
    self.failureMessage = failureMessage
    self.onRemoveItem = onRemoveItem
    self.onSendAll = onSendAll
    self.onClearAll = onClearAll
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header

      Divider()

      queuedItemList
    }
    .frame(maxWidth: .infinity)
    .background(Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: -4)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
    )
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 10) {
        Label("Queued Updates", systemImage: "square.stack.3d.up")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.primary)

        Text("\(queuedItems.count)")
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(
            Capsule()
              .fill(Color.secondary.opacity(0.15))
          )

        Text("These updates will attach to the next message you send.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Spacer()

        Button("Send") {
          onSendAll()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .help("Send queued updates")

        Button("Clear") {
          onClearAll()
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("Clear queued updates")
      }

      if let failureMessage {
        Label(failureMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
          .lineLimit(2)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }

  private var queuedItemList: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 6) {
        ForEach(queuedItems) { item in
          queuedItemRow(for: item)
            .transition(.opacity)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
    }
    .frame(maxHeight: min(CGFloat(max(queuedItems.count, 1)) * 56, 220))
    .animation(.easeInOut(duration: 0.25), value: queuedItems.map(\.id))
  }

  @ViewBuilder
  private func thumbnailView(for path: String?) -> some View {
    if let path, let nsImage = NSImage(contentsOfFile: path) {
      Image(nsImage: nsImage)
        .resizable()
        .scaledToFill()
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    } else {
      RoundedRectangle(cornerRadius: 6)
        .fill(Color.orange.opacity(0.15))
        .frame(width: 36, height: 36)
        .overlay {
          Image(systemName: path == nil ? "exclamationmark.triangle" : "photo")
            .font(.system(size: 14))
            .foregroundStyle(.orange.opacity(0.8))
        }
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
  }

  private func queuedItemRow(for item: WebPreviewQueuedUpdate) -> some View {
    HStack(alignment: .center, spacing: 6) {
      if item.isCrop {
        thumbnailView(for: item.cropScreenshotPath)
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Label(item.kindLabel, systemImage: item.iconName)
            .labelStyle(.titleAndIcon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
              RoundedRectangle(cornerRadius: 4)
                .fill(item.tint.opacity(0.85))
            )

          Text(item.summary)
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }

        Text(item.detail)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .truncationMode(.tail)
      }

      Spacer(minLength: 4)

      Button {
        onRemoveItem(item.id)
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 24, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Remove queued update")
    }
    .padding(6)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(NSColor.windowBackgroundColor).opacity(0.65))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
    )
  }
}

private extension WebPreviewQueuedUpdate {
  var tint: Color {
    switch selection {
    case .element:
      return instruction == nil ? .blue : .accentColor
    case .crop:
      return .orange
    }
  }

  var isCrop: Bool {
    if case .crop = selection { return true }
    return false
  }

  var cropScreenshotPath: String? {
    guard case .crop(let crop) = selection else { return nil }
    return crop.screenshotPath
  }
}
