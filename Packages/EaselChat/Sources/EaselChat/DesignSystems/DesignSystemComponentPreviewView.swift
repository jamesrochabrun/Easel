//
//  DesignSystemComponentPreviewView.swift
//  EaselChat
//

import EaselKit
import SwiftUI

struct DesignSystemComponentPreviewView: View {
  let title: String
  let summary: String
  let previewURL: URL?

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    Group {
      if let previewURL {
        AsyncImage(url: previewURL) { phase in
          switch phase {
          case .success(let image):
            image
              .resizable()
              .scaledToFit()
              .frame(maxWidth: .infinity)
              .background(Color.black)
          case .failure:
            placeholder
          case .empty:
            ProgressView()
              .frame(maxWidth: .infinity, minHeight: 220)
          @unknown default:
            placeholder
          }
        }
      } else {
        placeholder
      }
    }
    .frame(maxWidth: .infinity, minHeight: 220)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var placeholder: some View {
    VStack(alignment: .leading, spacing: 22) {
      Text(title.uppercased())
        .font(.caption.weight(.semibold))
        .foregroundStyle(.blue.opacity(0.65))

      VStack(alignment: .leading, spacing: 10) {
        RoundedRectangle(cornerRadius: 8)
          .fill(.white.opacity(0.92))
          .frame(width: 240, height: 52)
          .overlay(alignment: .leading) {
            HStack(spacing: 10) {
              Circle()
                .fill(.black.opacity(0.85))
                .frame(width: 16, height: 16)
              Text(title)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.black)
                .lineLimit(1)
            }
            .padding(.horizontal, 18)
          }

        Text(summary)
          .font(.callout)
          .foregroundStyle(.white.opacity(0.58))
          .lineLimit(2)
      }
    }
    .padding(34)
    .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
    .background(Color.black.opacity(colorScheme == .dark ? 0.92 : 0.95))
  }
}
