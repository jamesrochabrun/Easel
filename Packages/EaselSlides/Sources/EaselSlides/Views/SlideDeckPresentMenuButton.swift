//
//  SlideDeckPresentMenuButton.swift
//  EaselSlides
//

import AppKit
import SwiftUI

struct SlideDeckPresentMenuButton: NSViewRepresentable {
  let isEnabled: Bool
  let onSelect: @MainActor (SlideDeckPresentationOption) -> Void

  func makeNSView(context: Context) -> NSPopUpButton {
    let button = NSPopUpButton(frame: .zero, pullsDown: true)
    button.target = context.coordinator
    button.action = #selector(Coordinator.didSelectItem(_:))
    button.bezelStyle = .rounded
    button.controlSize = .small
    button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
    button.setAccessibilityLabel("Present slides")

    configure(button)
    return button
  }

  func updateNSView(_ button: NSPopUpButton, context: Context) {
    context.coordinator.parent = self
    configure(button)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  private func configure(_ button: NSPopUpButton) {
    button.removeAllItems()
    button.isEnabled = isEnabled

    button.addItem(withTitle: "Present")
    button.item(at: 0)?.image = Self.menuImage(systemName: "play.fill")

    for option in SlideDeckPresentationOption.allCases {
      button.addItem(withTitle: option.title)
      guard let item = button.item(at: button.numberOfItems - 1) else { continue }
      item.image = Self.menuImage(systemName: option.systemImage)
      item.representedObject = option.rawValue
    }

    button.selectItem(at: 0)
  }

  private static func menuImage(systemName: String) -> NSImage? {
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
    .applying(NSImage.SymbolConfiguration(paletteColors: [.labelColor]))

    let configuredImage = baseImage.withSymbolConfiguration(symbolConfiguration) ?? baseImage
    let image = configuredImage.copy() as? NSImage
    image?.isTemplate = false
    return image
  }

  @MainActor
  final class Coordinator: NSObject {
    var parent: SlideDeckPresentMenuButton

    init(parent: SlideDeckPresentMenuButton) {
      self.parent = parent
    }

    @objc
    func didSelectItem(_ sender: NSPopUpButton) {
      guard let rawValue = sender.selectedItem?.representedObject as? String,
            let option = SlideDeckPresentationOption(rawValue: rawValue) else {
        return
      }

      sender.selectItem(at: 0)
      parent.onSelect(option)
    }
  }
}
