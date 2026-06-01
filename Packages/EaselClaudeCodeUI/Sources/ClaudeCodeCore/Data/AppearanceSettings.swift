//
//  AppearanceSettings.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
public final class AppearanceSettings {
  // MARK: - Constants
  private enum Keys {
    static let fontSize = "fontSize"
    static let selectedTheme = "selectedTheme"
    static let customPrimaryHex = "customPrimaryHex"
    static let customSecondaryHex = "customSecondaryHex"
    static let customTertiaryHex = "customTertiaryHex"
  }
  
  private enum Defaults {
    static let fontSize: Double = 12.0
    static let theme: AppTheme = .codex
    static let customPrimaryHex = "#0F1110"
    static let customSecondaryHex = "#2E2F2F"
    static let customTertiaryHex = "#D9DAD6"
  }
  
  // MARK: - Properties
  var fontSize: Double {
    didSet {
      UserDefaults.standard.set(fontSize, forKey: Keys.fontSize)
    }
  }
  
  var selectedTheme: AppTheme {
    didSet {
      UserDefaults.standard.set(selectedTheme.rawValue, forKey: Keys.selectedTheme)
    }
  }

  // Custom theme colors (stored as hex strings)
  var customPrimaryHex: String {
    didSet {
      UserDefaults.standard.set(customPrimaryHex, forKey: Keys.customPrimaryHex)
    }
  }
  var customSecondaryHex: String {
    didSet {
      UserDefaults.standard.set(customSecondaryHex, forKey: Keys.customSecondaryHex)
    }
  }
  var customTertiaryHex: String {
    didSet {
      UserDefaults.standard.set(customTertiaryHex, forKey: Keys.customTertiaryHex)
    }
  }

  var themeColors: ThemeColors {
    ThemeColors.themeColors(
      for: selectedTheme,
      customPrimaryHex: customPrimaryHex,
      customSecondaryHex: customSecondaryHex,
      customTertiaryHex: customTertiaryHex
    )
  }
  
  // MARK: - Initialization
  init() {
    let storedFontSize = UserDefaults.standard.double(forKey: Keys.fontSize)
    self.fontSize = storedFontSize != 0 ? storedFontSize : Defaults.fontSize
    
    // Initialize theme
    let storedTheme = UserDefaults.standard.string(forKey: Keys.selectedTheme) ?? Defaults.theme.rawValue
    self.selectedTheme = AppTheme(rawValue: storedTheme) ?? Defaults.theme

    // Initialize custom theme colors
    self.customPrimaryHex = UserDefaults.standard.string(forKey: Keys.customPrimaryHex) ?? Defaults.customPrimaryHex
    self.customSecondaryHex = UserDefaults.standard.string(forKey: Keys.customSecondaryHex) ?? Defaults.customSecondaryHex
    self.customTertiaryHex = UserDefaults.standard.string(forKey: Keys.customTertiaryHex) ?? Defaults.customTertiaryHex
  }
}
