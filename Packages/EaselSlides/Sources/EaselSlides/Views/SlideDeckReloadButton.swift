//
//  SlideDeckReloadButton.swift
//  EaselSlides
//

import AppKit
import SwiftUI

struct SlideDeckReloadButton: NSViewRepresentable {
  let isEnabled: Bool
  let action: @MainActor () -> Void

  func makeNSView(context: Context) -> NSButton {
    let button = NSButton(
      title: "Reload",
      target: context.coordinator,
      action: #selector(Coordinator.didSelectReload(_:))
    )
    button.bezelStyle = .rounded
    button.controlSize = .small
    button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    button.imagePosition = .imageLeading
    button.setAccessibilityLabel("Reload slides")

    configure(button)
    return button
  }

  func updateNSView(_ button: NSButton, context: Context) {
    context.coordinator.parent = self
    configure(button)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  private func configure(_ button: NSButton) {
    button.title = "Reload"
    button.isEnabled = isEnabled
    button.image = Self.buttonImage(
      systemName: "arrow.clockwise",
      color: isEnabled ? .labelColor : .disabledControlTextColor
    )
  }

  private static func buttonImage(systemName: String, color: NSColor) -> NSImage? {
    guard let baseImage = NSImage(
      systemSymbolName: systemName,
      accessibilityDescription: nil
    ) else {
      return nil
    }

    let symbolConfiguration = NSImage.SymbolConfiguration(
      pointSize: 13,
      weight: .regular
    )
    .applying(NSImage.SymbolConfiguration(paletteColors: [color]))

    let configuredImage = baseImage.withSymbolConfiguration(symbolConfiguration) ?? baseImage
    let image = configuredImage.copy() as? NSImage
    image?.isTemplate = false
    return image
  }

  @MainActor
  final class Coordinator: NSObject {
    var parent: SlideDeckReloadButton

    init(parent: SlideDeckReloadButton) {
      self.parent = parent
    }

    @objc
    func didSelectReload(_ sender: NSButton) {
      parent.action()
    }
  }
}
