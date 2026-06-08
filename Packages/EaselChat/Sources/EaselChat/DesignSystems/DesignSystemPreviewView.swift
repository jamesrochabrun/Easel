//
//  DesignSystemPreviewView.swift
//  EaselChat
//

import EaselDesignSystems
import SwiftUI

/// Renders a locally-synthesized `EaselDesignSystemPreviewScene` by placing each
/// layer at its scene coordinates inside a fixed-size canvas, then uniformly
/// scaling to fit the available space. Mirrors the inline-SVG renderer used by
/// the generated `index.html` so both surfaces look the same.
struct DesignSystemPreviewView: View {
  let scene: EaselDesignSystemPreviewScene
  let workingDirectory: String?

  var body: some View {
    GeometryReader { proxy in
      let scale = min(
        proxy.size.width / max(scene.width, 1),
        proxy.size.height / max(scene.height, 1)
      )
      content
        .frame(width: scene.width, height: scene.height, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: scene.width * scale, height: scene.height * scale, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    .clipped()
  }

  private var content: some View {
    ZStack(alignment: .topLeading) {
      ForEach(scene.layers) { layer in
        layerView(layer)
          .frame(width: max(layer.width, 0), height: max(layer.height, 0), alignment: .leading)
          .clipped()
          .opacity(layer.opacity ?? 1)
          .offset(x: layer.x, y: layer.y)
      }
    }
  }

  @ViewBuilder
  private func layerView(_ layer: EaselDesignSystemPreviewLayer) -> some View {
    switch layer.kind {
    case .rect:
      RoundedRectangle(cornerRadius: layer.cornerRadius ?? 0, style: .continuous)
        .fill(color(layer.fill) ?? .clear)
        .overlay {
          if let stroke = color(layer.stroke) {
            RoundedRectangle(cornerRadius: layer.cornerRadius ?? 0, style: .continuous)
              .strokeBorder(stroke, lineWidth: layer.strokeWidth ?? 1)
          }
        }
    case .text:
      Text(layer.text ?? "")
        .font(.system(size: max(layer.fontSize ?? 12, 1), weight: weight(layer.fontWeight)))
        .foregroundStyle(color(layer.textColor) ?? .primary)
        .multilineTextAlignment(textAlignment(layer.align))
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: frameAlignment(layer.align))
        .clipped()
    case .image:
      if let url = fileURL(layer.imagePath) {
        AsyncImage(url: url) { phase in
          if let image = phase.image {
            image.resizable().scaledToFill()
          } else {
            Color.clear
          }
        }
        .clipped()
      } else {
        Color.clear
      }
    case .path:
      if let path = layer.path {
        ScenePath(svgPath: path)
          .fill(color(layer.fill) ?? .secondary)
      } else {
        Color.clear
      }
    }
  }

  private func color(_ hex: String?) -> Color? {
    guard let hex else { return nil }
    return Color(designSystemHex: hex)
  }

  private func weight(_ style: String?) -> Font.Weight {
    guard let style = style?.lowercased() else { return .regular }
    if style.contains("black") || style.contains("heavy") { return .heavy }
    if style.contains("bold") { return .bold }
    if style.contains("semi") { return .semibold }
    if style.contains("medium") { return .medium }
    if style.contains("light") || style.contains("thin") { return .light }
    return .regular
  }

  private func textAlignment(_ align: String?) -> TextAlignment {
    switch align?.uppercased() {
    case "CENTER": return .center
    case "RIGHT": return .trailing
    default: return .leading
    }
  }

  private func frameAlignment(_ align: String?) -> Alignment {
    switch align?.uppercased() {
    case "CENTER": return .center
    case "RIGHT": return .trailing
    default: return .leading
    }
  }

  private func fileURL(_ relativePath: String?) -> URL? {
    guard let relativePath, let workingDirectory, !relativePath.isEmpty else { return nil }
    return URL(fileURLWithPath: workingDirectory, isDirectory: true)
      .appendingPathComponent(relativePath)
  }
}

/// Minimal SVG path renderer for the absolute `M`/`L`/`C`/`Q`/`Z` commands
/// emitted by the parser's vector geometry (plus relative variants for safety).
/// The path is drawn in the layer's local coordinate space.
struct ScenePath: Shape {
  let svgPath: String

  func path(in rect: CGRect) -> Path {
    var path = Path()
    var index = svgPath.startIndex
    var current = CGPoint.zero
    var start = CGPoint.zero
    var command: Character = " "

    func readNumber() -> CGFloat? {
      skipSeparators()
      var numberString = ""
      var seenDot = false
      var seenExp = false
      while index < svgPath.endIndex {
        let char = svgPath[index]
        if char.isNumber {
          numberString.append(char)
        } else if char == "-" || char == "+" {
          if numberString.isEmpty || numberString.last == "e" || numberString.last == "E" {
            numberString.append(char)
          } else {
            break
          }
        } else if char == "." {
          if seenDot { break }
          seenDot = true
          numberString.append(char)
        } else if char == "e" || char == "E" {
          if seenExp { break }
          seenExp = true
          numberString.append(char)
        } else {
          break
        }
        index = svgPath.index(after: index)
      }
      return Double(numberString).map { CGFloat($0) }
    }

    func skipSeparators() {
      while index < svgPath.endIndex {
        let char = svgPath[index]
        if char == " " || char == "," || char == "\n" || char == "\t" || char == "\r" {
          index = svgPath.index(after: index)
        } else {
          break
        }
      }
    }

    func point(_ x: CGFloat, _ y: CGFloat, relative: Bool) -> CGPoint {
      relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
    }

    while index < svgPath.endIndex {
      skipSeparators()
      guard index < svgPath.endIndex else { break }
      let char = svgPath[index]
      if char.isLetter {
        command = char
        index = svgPath.index(after: index)
      }
      let relative = command.isLowercase
      switch command.uppercased().first {
      case "M":
        guard let x = readNumber(), let y = readNumber() else { return path }
        current = point(x, y, relative: relative)
        start = current
        path.move(to: current)
        command = relative ? "l" : "L"
      case "L":
        guard let x = readNumber(), let y = readNumber() else { return path }
        current = point(x, y, relative: relative)
        path.addLine(to: current)
      case "H":
        guard let x = readNumber() else { return path }
        current = CGPoint(x: relative ? current.x + x : x, y: current.y)
        path.addLine(to: current)
      case "V":
        guard let y = readNumber() else { return path }
        current = CGPoint(x: current.x, y: relative ? current.y + y : y)
        path.addLine(to: current)
      case "C":
        guard let c1x = readNumber(), let c1y = readNumber(),
              let c2x = readNumber(), let c2y = readNumber(),
              let x = readNumber(), let y = readNumber() else { return path }
        let control1 = point(c1x, c1y, relative: relative)
        let control2 = point(c2x, c2y, relative: relative)
        current = point(x, y, relative: relative)
        path.addCurve(to: current, control1: control1, control2: control2)
      case "Q":
        guard let cx = readNumber(), let cy = readNumber(),
              let x = readNumber(), let y = readNumber() else { return path }
        let control = point(cx, cy, relative: relative)
        current = point(x, y, relative: relative)
        path.addQuadCurve(to: current, control: control)
      case "Z":
        path.closeSubpath()
        current = start
      default:
        return path
      }
    }
    return path
  }
}
