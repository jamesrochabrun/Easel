//
//  DesignMarkdownFixtures.swift
//  EaselDesignSystemsTests
//

import Foundation

/// Fixtures are built from line arrays so YAML indentation is unambiguous
/// (independent of Swift multiline-literal de-indentation).
enum DesignMarkdownFixtures {
  /// A canonical, spec-clean sample.
  static let heritage = [
    "---",
    "version: alpha",
    "name: Heritage",
    "description: A premium editorial system.",
    "colors:",
    "  primary: \"#1A1C1E\"",
    "  secondary: \"#6C7278\"",
    "  tertiary: \"#B8422E\"",
    "  neutral: \"#F7F5F2\"",
    "typography:",
    "  display-lg:",
    "    fontFamily: Public Sans",
    "    fontSize: 3rem",
    "    fontWeight: 700",
    "  body-md:",
    "    fontFamily: Public Sans",
    "    fontSize: 1rem",
    "  label-caps:",
    "    fontFamily: Space Grotesk",
    "    fontSize: 0.75rem",
    "rounded:",
    "  sm: 4px",
    "  md: 8px",
    "spacing:",
    "  sm: 8px",
    "  md: 16px",
    "components:",
    "  button-primary:",
    "    backgroundColor: \"{colors.tertiary}\"",
    "    textColor: \"{colors.neutral}\"",
    "    rounded: \"{rounded.sm}\"",
    "    padding: 12px",
    "  button-primary-hover:",
    "    backgroundColor: \"{colors.secondary}\"",
    "---",
    "",
    "## Overview",
    "",
    "Architectural Minimalism meets Journalistic Gravitas.",
    "",
    "## Colors",
    "",
    "The palette is rooted in high-contrast neutrals.",
    "",
    "## Typography",
    "",
    "Public Sans carries the structural type.",
  ].joined(separator: "\n")

  /// An imperfect, third-party-style sample: aliased + out-of-order sections,
  /// no primary color, a low-contrast component, a broken ref, and an unknown key.
  static let imperfect = [
    "---",
    "name: Imperfect",
    "brandTone: playful", // unknown key
    "colors:",
    "  brand: \"#FFFFFF\"",
    "  ink: \"#AAAAAA\"",
    "components:",
    "  card:",
    "    backgroundColor: \"{colors.brand}\"",
    "    textColor: \"{colors.ink}\"", // ~2.3:1 contrast → fails AA
    "  banner:",
    "    backgroundColor: \"{colors.missing}\"", // broken ref
    "---",
    "",
    "## Colors",
    "",
    "Loud and friendly.",
    "",
    "## Overview", // out of order (Overview after Colors)
    "",
    "A playful identity.",
  ].joined(separator: "\n")
}
