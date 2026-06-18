//
//  DesignSystemReferenceView.swift
//  EaselChat
//

import EaselKit
import EaselDesignSystems
import SwiftUI

/// Renders a `.fig`-parsed catalog tokens-first: disclaimer, color swatches,
/// type specimens, spacing/radii/effect samples, component families with variant
/// metadata, examples, and source diagnostics. Preview slots resolve local file
/// URLs relative to the design system's working directory (populated in Phase 2).
struct DesignSystemReferenceView: View {
  let catalog: EaselDesignSystemCatalog
  let workingDirectory: String?

  @Environment(\.colorScheme) private var colorScheme

  @State private var selectedSectionID = ""
  @Namespace private var tabNamespace

  var body: some View {
    let sections = availableSections
    VStack(alignment: .leading, spacing: 0) {
      if let disclaimer = catalog.disclaimer, !disclaimer.isEmpty {
        disclaimerBanner(disclaimer)
          .padding(.horizontal, 28)
          .padding(.top, 20)
      }

      if sections.isEmpty {
        Spacer(minLength: 0)
      } else {
        tabCarousel(sections)

        Divider()
          .overlay(EaselDesignSystem.Palette.border(for: colorScheme))

        let active = resolvedSelection(in: sections)
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            sectionHeader(for: sections.first { $0.id == active })
            sectionContent(for: active)
          }
          .padding(.horizontal, 28)
          .padding(.top, 24)
          .padding(.bottom, 40)
          .frame(maxWidth: .infinity, alignment: .leading)
          .id(active)
          .transition(.opacity)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onAppear { ensureValidSelection(sections) }
    .onChange(of: catalog.name) { ensureValidSelection(availableSections) }
  }

  // MARK: - Tab model

  private struct ReferenceSection: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let count: Int?
    let unit: String?
  }

  private var availableSections: [ReferenceSection] {
    var result: [ReferenceSection] = []

    if let path = catalog.heroThumbnailPath, fileURL(for: path) != nil {
      result.append(.init(id: "overview", title: "Overview", icon: "photo", count: nil, unit: nil))
    }

    if let tokens = catalog.tokens {
      if !tokens.colors.isEmpty {
        result.append(.init(id: "colors", title: "Colors", icon: "paintpalette", count: tokens.colors.count, unit: "token"))
      }
      if !tokens.typography.isEmpty {
        result.append(.init(id: "typography", title: "Typography", icon: "textformat", count: tokens.typography.count, unit: "style"))
      }
      if !tokens.spacing.isEmpty {
        result.append(.init(id: "spacing", title: "Spacing", icon: "arrow.left.and.right", count: tokens.spacing.count, unit: "token"))
      }
      if !tokens.radii.isEmpty {
        result.append(.init(id: "radii", title: "Radii", icon: "rectangle.roundedtop", count: tokens.radii.count, unit: "token"))
      }
      if !tokens.effects.isEmpty {
        result.append(.init(id: "effects", title: "Effects", icon: "sparkles", count: tokens.effects.count, unit: "token"))
      }
    }

    if let families = catalog.componentFamilies, !families.isEmpty {
      result.append(.init(id: "families", title: "Components", icon: "square.on.square", count: families.count, unit: "family"))
    }

    if let examples = catalog.examples, !examples.isEmpty {
      result.append(.init(id: "examples", title: "Examples", icon: "rectangle.3.group", count: examples.count, unit: "frame"))
    }

    if catalog.sourceDiagnostics != nil {
      result.append(.init(id: "diagnostics", title: "Diagnostics", icon: "stethoscope", count: nil, unit: nil))
    }

    return result
  }

  private func resolvedSelection(in sections: [ReferenceSection]) -> String {
    if sections.contains(where: { $0.id == selectedSectionID }) { return selectedSectionID }
    return sections.first?.id ?? ""
  }

  private func ensureValidSelection(_ sections: [ReferenceSection]) {
    if !sections.contains(where: { $0.id == selectedSectionID }) {
      selectedSectionID = sections.first?.id ?? ""
    }
  }

  // MARK: - Tab carousel

  private func tabCarousel(_ sections: [ReferenceSection]) -> some View {
    let active = resolvedSelection(in: sections)
    return ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(sections) { section in
            tabChip(section, isActive: section.id == active)
              .id(section.id)
          }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
      }
      .onChange(of: selectedSectionID) { _, newValue in
        withAnimation(.smooth(duration: 0.3)) {
          proxy.scrollTo(newValue, anchor: .center)
        }
      }
    }
  }

  private func tabChip(_ section: ReferenceSection, isActive: Bool) -> some View {
    Button {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
        selectedSectionID = section.id
      }
    } label: {
      HStack(spacing: 7) {
        Image(systemName: section.icon)
          .font(.system(size: 12, weight: .semibold))
        Text(section.title)
          .font(.system(size: 13, weight: .semibold))
          .fixedSize()
        if let count = section.count {
          Text("\(count)")
            .font(.system(size: 11, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(
              isActive
                ? EaselDesignSystem.Palette.primaryActionForeground(for: colorScheme)
                : EaselDesignSystem.Palette.tertiaryText(for: colorScheme)
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(
              Capsule().fill(
                isActive
                  ? EaselDesignSystem.Palette.accent
                  : EaselDesignSystem.Palette.subtleSurface(for: colorScheme)
              )
            )
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .foregroundStyle(isActive ? Color.primary : EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      .background {
        if isActive {
          Capsule()
            .fill(EaselDesignSystem.Palette.surface(for: colorScheme))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 6, y: 2)
            .overlay(Capsule().stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1))
            .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(section.title)
    .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
  }

  // MARK: - Section header & content router

  @ViewBuilder
  private func sectionHeader(for section: ReferenceSection?) -> some View {
    if let section {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(section.title)
          .font(.system(size: 22, weight: .semibold))
        if let count = section.count, let unit = section.unit {
          Text(countLabel(count, unit: unit))
            .font(.subheadline)
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
        }
        Spacer(minLength: 0)
      }
    }
  }

  @ViewBuilder
  private func sectionContent(for id: String) -> some View {
    switch id {
    case "overview":
      if let path = catalog.heroThumbnailPath, let url = fileURL(for: path) {
        previewImage(url: url, aspectRatio: 16 / 9, contentMode: .fit)
          .frame(maxWidth: .infinity)
          .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.preview))
          .overlay {
            RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.preview)
              .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
          }
      }
    case "colors":
      colorSwatches(catalog.tokens?.colors ?? [])
    case "typography":
      typographySpecimens(catalog.tokens?.typography ?? [])
    case "spacing":
      spacingScale(catalog.tokens?.spacing ?? [])
    case "radii":
      radiusScale(catalog.tokens?.radii ?? [])
    case "effects":
      effectChips(catalog.tokens?.effects ?? [])
    case "families":
      familyGrid(catalog.componentFamilies ?? [])
    case "examples":
      exampleGrid(catalog.examples ?? [])
    case "diagnostics":
      if let diagnostics = catalog.sourceDiagnostics {
        diagnosticsBody(diagnostics)
      }
    default:
      EmptyView()
    }
  }

  private func countLabel(_ count: Int, unit: String) -> String {
    let plural = unit.hasSuffix("y") ? String(unit.dropLast()) + "ies" : unit + "s"
    return "\(count) \(count == 1 ? unit : plural)"
  }

  // MARK: - Disclaimer

  private func disclaimerBanner(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "info.circle")
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      Text(text)
        .font(.callout)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
    .overlay {
      RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
        .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
    }
  }

  // MARK: - Colors

  private func colorSwatches(_ colors: [EaselDesignSystemColorToken]) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], alignment: .leading, spacing: 14) {
      ForEach(colors) { color in
        VStack(alignment: .leading, spacing: 0) {
          RoundedRectangle(cornerRadius: 0)
            .fill(Color(designSystemHex: color.hex) ?? EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
            .frame(height: 64)
            .overlay(alignment: .topTrailing) {
              if Color(designSystemHex: color.hex) == nil {
                Image(systemName: "questionmark")
                  .font(.caption)
                  .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
                  .padding(6)
              }
            }
          VStack(alignment: .leading, spacing: 2) {
            Text(color.name)
              .font(.caption.weight(.semibold))
              .lineLimit(1)
            Text(color.hex)
              .font(EaselDesignSystem.Typography.code(size: 11))
              .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EaselDesignSystem.Palette.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
        .overlay {
          RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
      }
    }
  }

  // MARK: - Typography

  private func typographySpecimens(_ styles: [EaselDesignSystemTypographyToken]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(styles) { style in
        VStack(alignment: .leading, spacing: 6) {
          Text(style.name)
            .font(.system(size: sampleFontSize(style.fontSize), weight: fontWeight(for: style.fontStyle)))
            .lineLimit(1)
          Text(typographyDetail(for: style))
            .font(EaselDesignSystem.Typography.code(size: 11))
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
        .overlay {
          RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
      }
    }
  }

  private func sampleFontSize(_ size: Double?) -> CGFloat {
    guard let size else { return 17 }
    return min(max(CGFloat(size), 12), 40)
  }

  private func fontWeight(for style: String?) -> Font.Weight {
    guard let style = style?.lowercased() else { return .regular }
    if style.contains("black") || style.contains("heavy") { return .heavy }
    if style.contains("bold") { return .bold }
    if style.contains("semi") { return .semibold }
    if style.contains("medium") { return .medium }
    if style.contains("light") || style.contains("thin") { return .light }
    return .regular
  }

  private func typographyDetail(for style: EaselDesignSystemTypographyToken) -> String {
    var parts = [style.fontFamily]
    if let weight = style.fontStyle { parts.append(weight) }
    if let size = style.fontSize { parts.append("\(Int(size.rounded()))px") }
    return parts.joined(separator: " · ")
  }

  // MARK: - Spacing & radii

  private func spacingScale(_ tokens: [EaselDesignSystemNumberToken]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(tokens) { token in
        HStack(spacing: 14) {
          Text(token.name)
            .font(.callout)
            .frame(width: 130, alignment: .leading)
            .lineLimit(1)
          RoundedRectangle(cornerRadius: 3)
            .fill(EaselDesignSystem.Palette.accent)
            .frame(width: min(max(CGFloat(token.value), 2), 280), height: 14)
          Text("\(Int(token.value.rounded()))\(token.unit)")
            .font(EaselDesignSystem.Typography.code(size: 11))
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
          Spacer(minLength: 0)
        }
      }
    }
  }

  private func radiusScale(_ tokens: [EaselDesignSystemNumberToken]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      ForEach(tokens) { token in
        HStack(spacing: 14) {
          Text(token.name)
            .font(.callout)
            .frame(width: 130, alignment: .leading)
            .lineLimit(1)
          RoundedRectangle(cornerRadius: min(CGFloat(token.value), 28))
            .strokeBorder(EaselDesignSystem.Palette.accent, lineWidth: 2)
            .frame(width: 56, height: 36)
          Text("\(Int(token.value.rounded()))\(token.unit)")
            .font(EaselDesignSystem.Typography.code(size: 11))
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
          Spacer(minLength: 0)
        }
      }
    }
  }

  // MARK: - Effects

  private func effectChips(_ effects: [EaselDesignSystemEffectToken]) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], alignment: .leading, spacing: 8) {
      ForEach(effects) { effect in
        HStack(spacing: 6) {
          Text(effect.name)
            .font(.caption.weight(.medium))
            .lineLimit(1)
          Text(effect.kind)
            .font(EaselDesignSystem.Typography.code(size: 10))
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(EaselDesignSystem.Palette.surface(for: colorScheme), in: Capsule())
        .overlay { Capsule().stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1) }
      }
    }
  }

  // MARK: - Component families

  private func familyGrid(_ families: [EaselDesignSystemComponentFamily]) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], alignment: .leading, spacing: 14) {
      ForEach(families) { family in
        VStack(alignment: .leading, spacing: 0) {
          previewSlot(scene: family.preview, label: family.title)
            .frame(height: 130)
            .frame(maxWidth: .infinity)
            .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))

          VStack(alignment: .leading, spacing: 8) {
            Text(family.title)
              .font(.callout.weight(.semibold))
              .lineLimit(1)
            Text(familySubtitle(family))
              .font(.caption)
              .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
              .lineLimit(1)

            if !family.variantProperties.isEmpty {
              VStack(alignment: .leading, spacing: 6) {
                ForEach(family.variantProperties.prefix(4)) { property in
                  variantPropertyPill(property)
                }
              }
            }
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EaselDesignSystem.Palette.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
        .overlay {
          RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
      }
    }
  }

  private func familySubtitle(_ family: EaselDesignSystemComponentFamily) -> String {
    var parts: [String] = [family.category]
    if let page = family.sourcePage, !page.isEmpty { parts.append(page) }
    parts.append("\(family.variantCount) \(family.variantCount == 1 ? "variant" : "variants")")
    return parts.joined(separator: " · ")
  }

  private func variantPropertyPill(_ property: EaselDesignSystemVariantProperty) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      Text("\(property.name):")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
      Text(property.values.prefix(4).joined(separator: " · "))
        .font(.caption2)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
        .lineLimit(1)
    }
  }

  // MARK: - Examples

  private func exampleGrid(_ examples: [EaselDesignSystemExample]) -> some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], alignment: .leading, spacing: 12) {
      ForEach(examples) { example in
        VStack(alignment: .leading, spacing: 0) {
          previewSlot(scene: example.preview, label: example.title)
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme))
          VStack(alignment: .leading, spacing: 2) {
            Text(example.title)
              .font(.caption.weight(.medium))
              .lineLimit(1)
            if let page = example.sourcePage, !page.isEmpty {
              Text(page)
                .font(.caption2)
                .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
                .lineLimit(1)
            }
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(EaselDesignSystem.Palette.surface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
        .overlay {
          RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card)
            .stroke(EaselDesignSystem.Palette.border(for: colorScheme), lineWidth: 1)
        }
      }
    }
  }

  // MARK: - Diagnostics

  private func diagnosticsBody(_ diagnostics: EaselDesignSystemSourceDiagnostics) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(diagnosticsSummary(diagnostics))
        .font(.caption)
        .foregroundStyle(EaselDesignSystem.Palette.secondaryText(for: colorScheme))
      ForEach(Array(actionableWarnings(diagnostics.warnings).enumerated()), id: \.offset) { _, warning in
        HStack(alignment: .top, spacing: 6) {
          Image(systemName: "exclamationmark.triangle")
            .font(.caption2)
            .foregroundStyle(EaselDesignSystem.Palette.warning)
          Text(warning)
            .font(.caption)
            .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EaselDesignSystem.Palette.subtleSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: EaselDesignSystem.Radius.card))
  }

  private func actionableWarnings(_ warnings: [String]) -> [String] {
    warnings.filter { !Self.nonActionableDiagnosticWarnings.contains($0) }
  }

  private static let nonActionableDiagnosticWarnings: Set<String> = [
    "Component families are grouped by Figma layer name and may be noisy.",
    "Tokens are inferred from local node styles, not from a published token library.",
  ]

  private func diagnosticsSummary(_ diagnostics: EaselDesignSystemSourceDiagnostics) -> String {
    var parts: [String] = []
    if let parser = diagnostics.parserName {
      let version = diagnostics.parserVersion.map { " \($0)" } ?? ""
      parts.append("Parsed with \(parser)\(version)")
    }
    if diagnostics.totalNodeCount > 0 {
      parts.append("\(diagnostics.totalNodeCount) nodes")
    }
    if diagnostics.failedCount > 0 {
      parts.append("\(diagnostics.failedCount) failed")
    }
    return parts.isEmpty ? "Parsed locally." : parts.joined(separator: " · ")
  }

  // MARK: - Preview helpers

  @ViewBuilder
  private func previewSlot(scene: EaselDesignSystemPreviewScene?, label: String) -> some View {
    if let scene, !scene.layers.isEmpty {
      DesignSystemPreviewView(scene: scene, workingDirectory: workingDirectory)
        .padding(8)
        .accessibilityLabel("Schematic preview of \(label)")
    } else {
      Image(systemName: "square.dashed")
        .font(.title3)
        .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
        .accessibilityLabel("No preview for \(label)")
    }
  }

  @ViewBuilder
  private func previewImage(url: URL, aspectRatio: CGFloat?, contentMode: ContentMode) -> some View {
    AsyncImage(url: url) { phase in
      switch phase {
      case let .success(image):
        image
          .resizable()
          .aspectRatio(aspectRatio, contentMode: contentMode)
      case .failure:
        Image(systemName: "exclamationmark.triangle")
          .foregroundStyle(EaselDesignSystem.Palette.tertiaryText(for: colorScheme))
      default:
        ProgressView()
      }
    }
  }

  private func fileURL(for relativePath: String) -> URL? {
    guard let workingDirectory, !relativePath.isEmpty else { return nil }
    return URL(fileURLWithPath: workingDirectory, isDirectory: true)
      .appendingPathComponent(relativePath)
  }
}
