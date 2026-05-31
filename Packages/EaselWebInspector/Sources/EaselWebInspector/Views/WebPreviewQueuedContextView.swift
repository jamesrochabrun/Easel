//
//  WebPreviewQueuedContextView.swift
//  EaselWebInspector
//
//  Passive queue panel shown below the preview while web-preview updates are pending.
//

import AppKit
import EaselKit
import SwiftUI

public struct WebPreviewQueuedContextView: View {
  let queuedItems: [WebPreviewQueuedUpdate]
  let failureMessage: String?
  let onRemoveItem: (UUID) -> Void
  let onSendAll: () -> Void
  let onClearAll: () -> Void
  @Environment(\.colorScheme) private var colorScheme

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
    .background(EaselDesignSystem.Palette.surface(for: colorScheme))
    .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.preview))
    .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.12), radius: 10, x: 0, y: -4)
    .overlay(
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.preview)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
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
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(
            Capsule()
              .fill(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
          )

        Text("These updates will attach to the next message you send.")
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .lineLimit(1)

        Spacer()

        Button("Send") {
          onSendAll()
        }
        .buttonStyle(.borderedProminent)
        .tint(EaselDesignSystem.Palette.primaryAction(for: colorScheme))
        .controlSize(.small)
        .help("Send queued updates")

        Button("Clear") {
          onClearAll()
        }
        .buttonStyle(.plain)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .help("Clear queued updates")
      }

      if let failureMessage {
        Label(failureMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(EaselDesignSystem.Palette.warning)
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
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 0.5)
        )
    } else {
      RoundedRectangle(cornerRadius: 6)
        .fill(EaselDesignSystem.Palette.warning.opacity(0.15))
        .frame(width: 36, height: 36)
        .overlay {
          Image(systemName: path == nil ? "exclamationmark.triangle" : "photo")
            .font(.system(size: 14))
            .foregroundStyle(EaselDesignSystem.Palette.warning.opacity(0.8))
        }
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 0.5)
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
            .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
            .lineLimit(1)
            .truncationMode(.middle)
        }

        Text(item.detail)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .lineLimit(2)
          .truncationMode(.tail)
      }

      Spacer(minLength: 4)

      Button {
        onRemoveItem(item.id)
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
          .frame(width: 24, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Remove queued update")
    }
    .padding(6)
    .background(
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .fill(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
    )
    .overlay(
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    )
  }
}

private extension WebPreviewQueuedUpdate {
  var tint: Color {
    switch selection {
    case .element:
      return instruction == nil ? EaselDesignSystem.Palette.running : EaselDesignSystem.Palette.accent
    case .crop:
      return EaselDesignSystem.Palette.warning
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
