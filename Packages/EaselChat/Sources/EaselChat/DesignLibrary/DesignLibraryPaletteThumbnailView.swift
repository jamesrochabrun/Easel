//
//  DesignLibraryPaletteThumbnailView.swift
//  EaselChat
//

import EaselDesignSystems
import EaselKit
import SwiftUI

/// Renders a design system's identity as the card thumbnail: a band of color
/// swatches with a slanted lower edge, a floating "Aa Bb" type specimen, and a
/// base that adapts to light/dark so the band reads against the card surface.
struct DesignLibraryPaletteThumbnailView: View {
  let tokens: DesignSystemCardTokens

  @Environment(\.colorScheme) private var colorScheme

  private static let maxSwatches = 9

  private var swatches: [EaselDesignSystemColorToken] {
    Array(tokens.colors.prefix(Self.maxSwatches))
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        // Base fills the area beneath the slanted band; light or dark per mode.
        EaselDesignSystem.Palette.surfaceElevated(for: colorScheme)

        paletteBand
          .frame(height: proxy.size.height * 0.80)
          .clipShape(SlantedBottomShape(slant: 0.16))

        specimen
          .padding(.leading, 16)
          .padding(.top, 14)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var paletteBand: some View {
    HStack(spacing: 0) {
      ForEach(swatches) { token in
        swatchColor(for: token)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var specimen: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("Aa Bb")
        .font(specimenFont)
        .foregroundStyle(.white.opacity(0.92))
      Text(specimenLabel)
        .font(.system(size: 9, weight: .semibold))
        .tracking(1.6)
        .foregroundStyle(.white.opacity(0.55))
    }
    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
    .allowsHitTesting(false)
  }

  private func swatchColor(for token: EaselDesignSystemColorToken) -> Color {
    Color(designSystemHex: token.hex)
      ?? EaselDesignSystem.Palette.subtleSurface(for: colorScheme)
  }

  private var specimenFont: Font {
    if let family = tokens.primaryType?.fontFamily.trimmingCharacters(in: .whitespacesAndNewlines),
       !family.isEmpty {
      return .custom(family, size: 30).weight(.bold)
    }
    return .system(size: 30, weight: .bold, design: .serif)
  }

  private var specimenLabel: String {
    if let token = tokens.primaryType {
      let name = token.name.trimmingCharacters(in: .whitespacesAndNewlines)
      if !name.isEmpty { return name.uppercased() }
      if let style = token.fontStyle?.trimmingCharacters(in: .whitespacesAndNewlines), !style.isEmpty {
        return style.uppercased()
      }
    }
    return "SERIF"
  }
}

/// A rectangle whose bottom edge slopes down from left to right, used to give the
/// palette band a dynamic diagonal cut.
struct SlantedBottomShape: Shape {
  /// Fraction of the height by which the left edge sits above the right edge.
  var slant: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let leftRise = rect.height * slant
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - leftRise))
    path.closeSubpath()
    return path
  }
}
